#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
tmp_artifact="$1"
slugdir="$2"

chillbox_owner="$(cat /var/lib/chillbox/owner)"

test -n "${tmp_artifact}" || (echo "ERROR $script_name: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $script_name: The $tmp_artifact is not a file" && exit 1)

test -n "${SLUGNAME}" || (echo "ERROR $script_name: SLUGNAME variable is empty" && exit 1)

test -n "${slugdir}" || (echo "ERROR $script_name: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $script_name: slugdir should be a directory" && exit 1)
test -d "$(dirname "${slugdir}")" || (echo "ERROR $script_name: parent directory of slugdir should be a directory" && exit 1)


# Redis instance for a site is optional
has_redis="$(jq -r -e 'has("redis")' "/etc/chillbox/sites/$SLUGNAME.site.json" || printf "")"
if [ "$has_redis" = "false" ]; then
  echo "INFO $script_name: No redis defined for $SLUGNAME."
  exit 0
elif [ "$has_redis" = "true" ]; then
  echo "INFO $script_name: Setting up redis instance for $SLUGNAME."
else
  echo "ERROR $script_name: Unhandled response for $SLUGNAME."
  exit 1
fi

mkdir -p "/var/lib/redis/$SLUGNAME"
chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/redis/$SLUGNAME"
chmod 0770 "/var/lib/redis/$SLUGNAME"
mkdir -p "/etc/chillbox/redis/$SLUGNAME/"
# The users.acl file should be extracted from the tar file.
tar x -z -C "/etc/chillbox/redis/$SLUGNAME/" -f "$tmp_artifact" --strip-components=2 "$SLUGNAME/redis"
# Generate a random password that can be manually used by the chillbox owner.
cb_owner_redis_pass="$(openssl rand 1111 | base64 -w 0 | tr -d '[:punct:]')"
# The chillbox owner is meant to only be used when troubleshooting or investigating.
cat <<APPEND_CB_OWNER_USER >> "/etc/chillbox/redis/$SLUGNAME/users.acl"
user $chillbox_owner on >$cb_owner_redis_pass allchannels allkeys +@all
APPEND_CB_OWNER_USER
cp /etc/chillbox/redis/redis.conf "/etc/chillbox/redis/$SLUGNAME/"
chown -R "$SLUGNAME":"$SLUGNAME" "/etc/chillbox/redis/$SLUGNAME/"
chmod -R 0700 "/etc/chillbox/redis/$SLUGNAME/"

# Only for openrc
mkdir -p /etc/init.d
cat <<PURR > "/etc/init.d/${SLUGNAME}-redis"
#!/sbin/openrc-run
supervisor=s6
name="${SLUGNAME}-redis"
procname="${SLUGNAME}-redis"
description="${SLUGNAME}-redis"
s6_service_path=/etc/services.d/${SLUGNAME}-redis
depend() {
  need s6-svscan
}
PURR
chmod +x "/etc/init.d/${SLUGNAME}-redis"

# Need all the redis conf options to be on a single line.
site_redis_options="$(jq -r '.redis | to_entries | .[] | "--\(.key) " + "\(.value)"' "/etc/chillbox/sites/$SLUGNAME.site.json" | xargs)"

mkdir -p /run/redis
chmod 0777 /run/redis
mkdir -p "/etc/services.d/${SLUGNAME}-redis"
# The site_redis_options come before the rest of the chillbox specific options
# to override them. For example, the redis instance is only available on a unix
# socket and not a tcp port, so the --port will always be set to 0.
cat <<PURR > "/etc/services.d/${SLUGNAME}-redis/run"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
fdmove -c 2 1
redis-server "/etc/chillbox/redis/$SLUGNAME/redis.conf" \
  $site_redis_options \
  --port 0 \
  --bind "127.0.0.1" \
  --protected-mode "yes" \
  --dir "/var/lib/redis/$SLUGNAME" \
  --aclfile "/etc/chillbox/redis/$SLUGNAME/users.acl" \
  --unixsocket "/run/redis/$SLUGNAME.sock"
PURR
chmod +x "/etc/services.d/${SLUGNAME}-redis/run"

# Add logging
mkdir -p "/etc/services.d/${SLUGNAME}-redis/log"
cat <<PURR > "/etc/services.d/${SLUGNAME}-redis/log/run"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
s6-log n3 s1000000 T /var/log/${SLUGNAME}-redis
PURR
chmod +x "/etc/services.d/${SLUGNAME}-redis/log/run"

# Enable protection against constantly restarting a failing service.
cat <<PURR > "/etc/services.d/${SLUGNAME}-redis/finish"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
s6-permafailon 60 5 1-255,SIGSEGV,SIGBUS
PURR
chmod +x "/etc/services.d/${SLUGNAME}-redis/finish"

rc-update add "${SLUGNAME}-redis" default
rc-service "${SLUGNAME}-redis" start
