#!/usr/bin/env sh

set -o errexit

# Always source the chillbox.config before the .env to prevent chillbox.config
# overwriting settings that are in the .env.
# shellcheck disable=SC1091
. /etc/chillbox/chillbox.config
# shellcheck disable=SC1091
. /home/dev/.env

mkdir -p /usr/local/src/
cd /usr/local/src/


now_iso_seconds="$(date -Iseconds)"
chillbox_update_log="/var/log/chillbox-update/$now_iso_seconds.log"
chillbox_update_log_dir="$(dirname "$chillbox_update_log")"
mkdir -p "$chillbox_update_log_dir"
touch "$chillbox_update_log"
chmod 0640 "$chillbox_update_log"
chown root:ansibledev "$chillbox_update_log"

/etc/chillbox/bin/site-init.sh >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)

/etc/chillbox/bin/reload-templates.sh >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)
nginx -t >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)
nginx -t && rc-service nginx reload

cat "$chillbox_init_log"
