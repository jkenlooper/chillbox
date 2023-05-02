#{#-
## This script should be inlined inside a user-data script.
#}

cat <<'AUTO_DECRYPT_FILE' > "/usr/local/bin/auto-decrypt-file.sh"
#!/usr/bin/env sh
set -o errexit
set -o nounset

test "$(id -u)" -eq "0" || (echo "Must be root." && exit 1)

key_name="$(hostname -s | xargs)"

ciphertext_file="$1"
owner="_"
dest_path="_"
tmp_export="$(mktemp)"
echo "$ciphertext_file" \
  | sed -n 's:\({{ CHILLBOX_PATH_SENSITIVE }}\|{{ CHILLBOX_PATH_SECRETS }}\)/\([^/]\+\)\(.*\):export owner="\2";export dest_path="\3":p' \
  > "$tmp_export"
. "$tmp_export"
rm -f "$tmp_export"

touch "$dest_path"
chown "$owner" "$dest_path"
chmod go-rwx "$dest_path"
chmod u+r "$dest_path"
/usr/local/bin/decrypt-file -k /root/chillbox/key/${key_name}.private.pem -i "$ciphertext_file" "$dest_path"
AUTO_DECRYPT_FILE
chmod u+x "/usr/local/bin/auto-decrypt-file.sh"

mkdir -p "/usr/local/bin"
cat <<CHILLBOX_WATCH_PATHS_SCRIPT > "/usr/local/bin/watch-chillbox-secrets-and-sensitive-paths.sh"
#!/usr/bin/env sh
set -o errexit
echo "INFO $0\n  Starting watch process."
cat <<'CHILLBOX_PATH_LIST' | entr -a -d -d -n -p -r /usr/local/bin/auto-decrypt-file.sh /_
{{ CHILLBOX_PATH_SENSITIVE }}
{{ CHILLBOX_PATH_SECRETS }}
CHILLBOX_PATH_LIST
CHILLBOX_WATCH_PATHS_SCRIPT
chmod u+x "/usr/local/bin/watch-chillbox-secrets-and-sensitive-paths.sh"

mkdir -p /etc/init.d
cat <<MEOW > /etc/init.d/chillbox-trigger-watch-secrets-and-sensitive-paths
#!/sbin/openrc-run
supervisor=s6
name="chillbox-trigger-watch-secrets-and-sensitive-paths"
procname="chillbox-trigger-watch-secrets-and-sensitive-paths"
description="Watch the {{ CHILLBOX_PATH_SENSITIVE }} and {{ CHILLBOX_PATH_SECRETS }} directories for changes"
s6_service_path=/etc/services.d/chillbox-trigger-watch-secrets-and-sensitive-paths
depend() {
  need s6-svscan
}
MEOW
chmod +x "/etc/init.d/chillbox-trigger-watch-secrets-and-sensitive-paths"

mkdir -p "/etc/services.d/chillbox-trigger-watch-secrets-and-sensitive-paths"
cat <<PURR > "/etc/services.d/chillbox-trigger-watch-secrets-and-sensitive-paths/run"
#!/usr/bin/execlineb -P
s6-setuidgid root
fdmove -c 2 1
/usr/local/bin/watch-chillbox-secrets-and-sensitive-paths.sh
PURR
chmod +x "/etc/services.d/chillbox-trigger-watch-secrets-and-sensitive-paths/run"
rc-update add "chillbox-trigger-watch-secrets-and-sensitive-paths" default
rc-service "chillbox-trigger-watch-secrets-and-sensitive-paths" start

