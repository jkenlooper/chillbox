#!/usr/bin/env sh

set -o errexit

LETS_ENCRYPT_SERVER="${LETS_ENCRYPT_SERVER:-''}"
test -n "${LETS_ENCRYPT_SERVER}" || (echo "ERROR $0: LETS_ENCRYPT_SERVER variable is empty" && exit 1)
test "${LETS_ENCRYPT_SERVER}" = "letsencrypt" \
  || test "${LETS_ENCRYPT_SERVER}" = "letsencrypt_test" \
  || (echo "ERROR $0: LETS_ENCRYPT_SERVER variable should be either letsencrypt or letsencrypt_test" && exit 1)
echo "INFO $0: Using LETS_ENCRYPT_SERVER '${LETS_ENCRYPT_SERVER}'"

# Create certs for all sites
mkdir -p /var/lib/acmesh
chown -R nginx:nginx /var/lib/acmesh

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')

for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#/etc/chillbox/sites/}
  export slugname
  domain_list="$(jq -r '.domain_list[]' "$site_json")"
  # Reset and add the --domain option for each to the $@ variable
  set -- ""
  for domain in $domain_list; do
    set -- "$@" --domain "$domain"
  done

  acme.sh --issue \
    --server "$LETS_ENCRYPT_SERVER" \
    "$@" \
    --webroot "/srv/$slugname/root/"

  acme.sh --install-cert \
    --server "$LETS_ENCRYPT_SERVER" \
    "$@" \
    --cert-file "/var/lib/acmesh/$slugname.cer" \
    --key-file "/var/lib/acmesh/$slugname.key" \
    --reloadcmd 'nginx -t && nginx -s reload'
done
