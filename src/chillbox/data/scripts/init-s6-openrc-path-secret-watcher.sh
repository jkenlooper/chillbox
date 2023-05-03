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

is_path_sensitive="$(echo "$ciphertext_file" | grep -e '^{{ CHILLBOX_PATH_SENSITIVE }}' - || echo "no")"
if [ "$is_path_sensitive" = "no" ]; then
  dest_path_dir="$(dirname "$dest_path")"
  mkdir -p "$dest_path_dir"
  touch "$dest_path"
  chown "$owner" "$dest_path"
  chmod go-rwx "$dest_path"
  chmod u+r "$dest_path"
  chmod u-w "$dest_path"
  /usr/local/bin/decrypt-file -k /root/chillbox/key/${key_name}.private.pem -i "$ciphertext_file" "$dest_path"
else
  tmp_dest_path_gz="$(mktemp)"
  /usr/local/bin/decrypt-file -k /root/chillbox/key/${key_name}.private.pem -i "$ciphertext_file" "$tmp_dest_path_gz"
  tmp_dest_path="$(mktemp)"
  gunzip -c -f "$tmp_dest_path_gz" > "$tmp_dest_path"
  rm -f "$tmp_dest_path_gz"
  is_tar="$(tar t -f "$tmp_dest_path" > /dev/null 2>&1 || echo "no")"
  if [ "$is_tar" = "no" ]; then
    dest_path_dir="$(dirname "$dest_path")"
    mkdir -p "$dest_path_dir"
    touch "$dest_path"
    chown "$owner" "$dest_path"
    chmod go-rwx "$dest_path"
    chmod u+r "$dest_path"
    chmod u-w "$dest_path"
    dd if="$tmp_dest_path" of="$dest_path" 2> /dev/null
  else
    mkdir -p "$dest_path"
    tar x -f "$tmp_dest_path" -C "$dest_path" --strip-components 1
  fi
  rm -f "$tmp_dest_path"
fi

AUTO_DECRYPT_FILE
chmod u+x "/usr/local/bin/auto-decrypt-file.sh"

mkdir -p "/usr/local/bin"
cat <<'CHILLBOX_WATCH_PATHS_SCRIPT' > "/usr/local/bin/watch-chillbox-secrets-and-sensitive-paths.sh"
#!/usr/bin/env sh
echo "INFO $0\n  Starting watch process."
tmp_watch_list="$(mktemp)"
find {{ CHILLBOX_PATH_SENSITIVE }} -type f >> "$tmp_watch_list"
find {{ CHILLBOX_PATH_SECRETS }} -type f >> "$tmp_watch_list"
entr -n -r -d /usr/local/bin/auto-decrypt-file.sh /_ < "$tmp_watch_list"
rm -f "$tmp_watch_list"
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

