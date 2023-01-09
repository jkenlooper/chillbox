#!/usr/bin/env sh

set -o errexit

ACME_SERVER="${ACME_SERVER:-''}"
test -n "${ACME_SERVER}" || (echo "ERROR $0: ACME_SERVER variable is empty" && exit 1)
echo "INFO $0: Using ACME_SERVER '${ACME_SERVER}'"

# Create certs for all sites
mkdir -p /var/lib/acmesh
chown -R nginx:nginx /var/lib/acmesh

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')

for site_json in $sites; do
  slugname="$(basename "$site_json" .site.json)"
  domain_list="$(jq -r '.domain_list[]' "$site_json")"
  # Reset and add the --domain option for each to the $@ variable
  set -- ""
  for domain in $domain_list; do
    set -- "$@" --domain "$domain"
  done

  set -x
  acme.sh --issue \
    --server "$ACME_SERVER" \
    "$@" \
    --webroot "/srv/$slugname/root/"

  acme.sh --install-cert \
    --server "$ACME_SERVER" \
    "$@" \
    --cert-file "/var/lib/acmesh/$slugname.cer" \
    --key-file "/var/lib/acmesh/$slugname.key" \
    --reloadcmd 'nginx -t && rc-service nginx reload'
  set +x
done
