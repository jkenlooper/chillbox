#!/usr/bin/env sh

set -o errexit

acme_server="${ACME_SERVER:-https://acme-staging-v02.api.letsencrypt.org/directory}"
acme_hostname="$(echo "$acme_server" | sed -E 's%https://([^/]+)/?.*%\1%')"

tmp_accounts_tar_b64="$(mktemp)"
tmp_config="$(mktemp -d)"
tmp_wd="$(mktemp -d)"
tmp_logs="$(mktemp -d)"

certbot register \
    --server "$acme_server" \
    --config-dir "$tmp_config" \
    --work-dir "$tmp_wd" \
    --logs-dir "$tmp_logs" \
    --register-unsafely-without-email

tar c \
  -f - \
  -C "$tmp_config/accounts/$acme_hostname" \
  directory | base64 > "$tmp_accounts_tar_b64"

chmod -R u+w "$tmp_config"
for tmp_d in "$tmp_config" "$tmp_wd" "$tmp_logs"; do
    find "$tmp_d" -type f \
      -exec sh -c 'shred -z -u "$1" || rm -f "$1"' shell {} \;
    rm -rf "$tmp_d"
done

echo "$tmp_accounts_tar_b64"
