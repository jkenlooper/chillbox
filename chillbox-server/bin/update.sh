#!/usr/bin/env sh

set -o errexit

chillbox_owner="$(cat /var/lib/chillbox/owner)"

test -n "$ACME_SERVER" || (echo "No ACME_SERVER variable set. Exiting" && exit 1)

mkdir -p /usr/local/src/
cd /usr/local/src/


now_iso_seconds="$(date -Iseconds)"
chillbox_update_log="/var/log/chillbox-update/$now_iso_seconds.log"
chillbox_update_log_dir="$(dirname "$chillbox_update_log")"
mkdir -p "$chillbox_update_log_dir"
touch "$chillbox_update_log"
chmod 0640 "$chillbox_update_log"
chown "root:$chillbox_owner" "$chillbox_update_log"

/etc/chillbox/bin/site-init.sh >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)

/etc/chillbox/bin/reload-templates.sh >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)

if [ "$ENABLE_CERTBOT" = "true" ]; then
  mkdir -p /etc/chillbox/sites/.has-certs
  chown -R "$chillbox_owner" /etc/chillbox/sites/.has-certs
  su "$chillbox_owner" '/etc/chillbox/bin/issue-and-install-certs.sh' || echo "WARNING: Failed to run issue-and-install-certs.sh"
  /etc/chillbox/bin/reload-templates.sh >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)

  # Renew after issue-and-install-certs.sh in case it downloaded an almost expired
  # cert from s3 object storage. This helps prevent a gap from happening if the
  # cron job to renew doesn't happen in time.
  # The crontab for certbot renew is set in chillbox-init.sh.
  su "$chillbox_owner" -c "certbot renew --user-agent-comment 'chillbox/0.0' --server '$ACME_SERVER'"
fi

nginx -t >> "$chillbox_update_log" 2>&1 || (cat "$chillbox_update_log" && exit 1)
nginx -t && rc-service nginx reload

cat "$chillbox_update_log"
