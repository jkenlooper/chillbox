#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

ACME_SERVER="${ACME_SERVER:-''}"
test -n "${ACME_SERVER}" || (echo "ERROR $script_name: ACME_SERVER variable is empty" && exit 1)
echo "INFO $script_name: Using ACME_SERVER '${ACME_SERVER}'"

# Conditionally get cert for chillbox. Only one domain is used for chillbox.
if [ -e "/etc/letsencrypt/live/chillbox/fullchain.pem" ] && [ -e "/etc/letsencrypt/live/chillbox/privkey.pem" ]; then
  echo "INFO $script_name: Using existing ssl certs for chillbox."
else
  # Exit without trying to get other site ssl certs if getting the chillbox cert
  # fails. This means that most likely all the other requests to get certs will
  # fail.
  certbot certonly \
    --user-agent-comment "chillbox/0.0" \
    --server "$ACME_SERVER" \
    --non-interactive \
    --webroot \
    --webroot-path "/srv/chillbox" \
    --cert-name "chillbox" \
    --domain "$CHILLBOX_SERVER_NAME" \
      || (echo "ERROR $script_name: Failed to get new ssl cert for chillbox" && exit 1)
fi

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')

for site_json in $sites; do
  slugname="$(basename "$site_json" .site.json)"
  domain_list="$(jq -r '.domain_list[]' "$site_json")"

  # Optimize by only getting new certs if the domain_list has changed instead of
  # replacing certs that are still valid.
  domain_list_hash="$(echo "$domain_list" | md5sum | cut -d' ' -f1)"
  if [ -e "/etc/letsencrypt/live/$slugname/fullchain.pem" ] && [ -e "/etc/letsencrypt/live/$slugname/privkey.pem" ]; then
    if [ -e "/etc/chillbox/sites/.$slugname-domain_list_hash" ]; then
      previous_domain_list_hash="$(cat "/etc/chillbox/sites/.$slugname-domain_list_hash")"
      if [ "$previous_domain_list_hash" = "$domain_list_hash" ]; then
        echo "INFO $script_name: Using existing ssl certs for $slugname."
        continue
      fi
    fi
  fi

  # Reset and add the --domain option for each to the $@ variable
  set -- ""
  for domain in $domain_list; do
    set -- "$@" --domain "$domain"
  done

  # Save the cert to /etc/letsencrypt/live/
  # https://eff-certbot.readthedocs.io/en/stable/using.html#webroot
  set -x
  certbot certonly \
    --user-agent-comment "chillbox/0.0" \
    --server "$ACME_SERVER" \
    --non-interactive \
    --webroot \
    --webroot-path "/srv/$slugname" \
    --cert-name "$slugname" \
    "$@" || (echo "WARNING $script_name: Failed to get new ssl cert for $slugname" && continue)
  set +x
  # Only create the domain_list_hash file if getting a ssl cert was successful.
  printf "%s" "$domain_list_hash" > "/etc/chillbox/sites/.$slugname-domain_list_hash"

done

# TODO Add crontab to renew certs and reload nginx 'nginx -t && rc-service nginx reload'.

