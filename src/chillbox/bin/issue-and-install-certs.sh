#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

test -n "${ACME_SERVER}" || (echo "ERROR $script_name: ACME_SERVER variable is empty" && exit 1)
echo "INFO $script_name: Using ACME_SERVER '${ACME_SERVER}'"

test -n "${CHILLBOX_SERVER_NAME}" || (echo "ERROR $script_name: CHILLBOX_SERVER_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using CHILLBOX_SERVER_NAME '${CHILLBOX_SERVER_NAME}'"

# Should not need to be root when running certbot commands.
current_user="$(id -u -n)"
test "$current_user" != "root" || (echo "ERROR $script_name: Must not be root. This script is executing certbot commands and should not require root." && exit 1)

get_cert() {
  cert_name="$1"
  shift 1

  domain_list="$*"

  # Optimize by only getting new certs if the domain_list has changed instead of
  # replacing certs that are still valid. The domain_list_hash is used as the
  # key prefix for certs saved to s3 object storage.
  domain_list_hash="$(echo "$domain_list" | md5sum | cut -d' ' -f1)"

  has_cert="unknown"

  if [ -e "/etc/letsencrypt/live/$cert_name/fullchain.pem" ] \
    && [ -e "/etc/letsencrypt/live/$cert_name/privkey.pem" ] \
    && [ -e "/etc/chillbox/sites/.$cert_name-$domain_list_hash" ]; then
      echo "INFO $script_name: Using existing ssl certs for $cert_name."
      has_cert="yes"
  fi

  if [ "$has_cert" != "yes" ]; then
    echo "TODO $script_name: Check s3 for encrypted $cert_name-$domain_list_hash cert."
    # TODO Check if the encrypted certs are in s3 under the $cert_name-$domain_list_hash prefix key.
    # TODO Decrypt and install fullchain.pem and privkey.pem
    if [ -e "/etc/letsencrypt/live/$cert_name/fullchain.pem" ] \
      && [ -e "/etc/letsencrypt/live/$cert_name/privkey.pem" ]; then
        has_cert="yes"
    fi
  fi

  if [ "$has_cert" != "yes" ]; then

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
      --webroot-path "/srv/$cert_name" \
      --cert-name "$cert_name" \
      "$@"
    set +x
    # TODO Encrypt and upload the certs to s3 under the $cert_name-$domain_list_hash prefix key.
    # TODO Set a life-cycle rule to expire the cert in s3 after 30 days. Certs
    # should be valid for 90 days when using letsencrypt.
    # https://letsencrypt.org/docs/integration-guide/#when-to-renew
    has_cert="yes"
  fi

  if [ "$has_cert" = "yes" ]; then
    # Only recreate the domain_list_hash file if getting a ssl cert was successful.
    printf "%s" "$domain_list" > "/etc/chillbox/sites/.$cert_name-$domain_list_hash"
  fi
}

# Conditionally get cert for chillbox. Only one domain is used for chillbox.
# TODO handle hostname domains if they have been set.

# Exit without trying to get other site ssl certs if getting the chillbox cert
# fails. This means that most likely all the other requests to get certs will
# fail.
get_cert chillbox "$CHILLBOX_SERVER_NAME" \
  || (echo "ERROR $script_name: Failed to get new ssl cert for chillbox" && exit 1)

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname="$(basename "$site_json" .site.json)"
  domain_list="$(jq -r '.domain_list[]' "$site_json")"
  get_cert "$slugname" "$domain_list" || continue
done
