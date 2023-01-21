#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

test -n "${ACME_SERVER}" || (echo "ERROR $script_name: ACME_SERVER variable is empty" && exit 1)
echo "INFO $script_name: Using ACME_SERVER '${ACME_SERVER}'"

test -n "${CHILLBOX_SERVER_NAME}" || (echo "ERROR $script_name: CHILLBOX_SERVER_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using CHILLBOX_SERVER_NAME '${CHILLBOX_SERVER_NAME}'"

test -n "${MANAGE_HOSTNAME_DNS_RECORDS}" || (echo "ERROR $script_name: MANAGE_HOSTNAME_DNS_RECORDS variable is empty" && exit 1)
echo "INFO $script_name: Using MANAGE_HOSTNAME_DNS_RECORDS '${MANAGE_HOSTNAME_DNS_RECORDS}'"

test -n "${MANAGE_DNS_RECORDS}" || (echo "ERROR $script_name: MANAGE_DNS_RECORDS variable is empty" && exit 1)
echo "INFO $script_name: Using MANAGE_DNS_RECORDS '${MANAGE_DNS_RECORDS}'"

# Should not need to be root when running certbot commands.
current_user="$(id -u -n)"
test "$current_user" != "root" || (echo "ERROR $script_name: Must not be root. This script is executing certbot commands and should not require root." && exit 1)

get_cert() {
  cert_name="$1"
  shift 1

  domain_list="$*"

  echo "INFO $script_name: Get $cert_name ssl certs for domain list: $domain_list"

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
    # The webroot path is set to /srv/chillbox because Chillbox manages the
    # *.ssl_cert.include file with reload-templates.sh.
    set -x
    certbot certonly \
      --user-agent-comment "chillbox/0.0" \
      --server "$ACME_SERVER" \
      --non-interactive \
      --webroot \
      --webroot-path "/srv/chillbox" \
      --cert-name "$cert_name" \
      "$@"
    set +x
    # TODO Encrypt and upload the certs to s3 under the $cert_name-$domain_list_hash prefix key.
    # TODO Set a life-cycle rule to expire the cert in s3 after 30 days. Certs
    # should be valid for 90 days when using letsencrypt.
    # https://letsencrypt.org/docs/integration-guide/#when-to-renew
    if [ -e "/etc/letsencrypt/live/$cert_name/fullchain.pem" ] \
      && [ -e "/etc/letsencrypt/live/$cert_name/privkey.pem" ]; then
        has_cert="yes"
    fi
  fi

  if [ "$has_cert" = "yes" ]; then
    echo "INFO $script_name: Success getting $cert_name ssl certs for domain list: $domain_list"
    # Only recreate the domain_list_hash file if getting a ssl cert was successful.
    printf "%s" "$domain_list" > "/etc/chillbox/sites/.$cert_name-$domain_list_hash"
  fi
}

# First try to get the certs for chillbox itself and fail early. This way the
# script avoids trying to get certs for the site domains which would probably
# fail as well.

if [ "$MANAGE_DNS_RECORDS" = "true" ]; then
  get_cert chillbox "$CHILLBOX_SERVER_NAME" \
    || (echo "ERROR $script_name: Failed to get new ssl cert for chillbox ($CHILLBOX_SERVER_NAME)." && exit 1)
fi

hostname_chillbox="$(hostname).$CHILLBOX_SERVER_NAME"
if [ "$MANAGE_HOSTNAME_DNS_RECORDS" = "true" ]; then
  get_cert hostname-chillbox "$hostname_chillbox" \
    || (echo "ERROR $script_name: Failed to get new ssl cert for chillbox hostname ($hostname_chillbox)." && exit 1)
fi

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname="$(basename "$site_json" .site.json)"
  domain_list="$(jq -r '.domain_list[]' "$site_json")"
  if [ "$MANAGE_DNS_RECORDS" = "true" ]; then
    get_cert "$slugname" "$domain_list" || continue
  fi
  if [ "$MANAGE_HOSTNAME_DNS_RECORDS" = "true" ]; then
    hostname_domain_list="$(jq -r --arg jq_hostname_chillbox "${hostname_chillbox}." '.domain_list[] | $jq_hostname_chillbox + .' "$site_json")"
    get_cert "hostname-$slugname" "$hostname_domain_list" || continue
  fi
done