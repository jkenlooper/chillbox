#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

test -n "${ACME_SERVER}" || (echo "ERROR $script_name: ACME_SERVER variable is empty" && exit 1)
echo "INFO $script_name: Using ACME_SERVER '${ACME_SERVER}'"

test -n "${CHILLBOX_SERVER_NAME}" || (echo "ERROR $script_name: CHILLBOX_SERVER_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using CHILLBOX_SERVER_NAME '${CHILLBOX_SERVER_NAME}'"
if [ "${#CHILLBOX_SERVER_NAME}" -gt 59 ]; then
  echo "ERROR $script_name: The domain lt64.$CHILLBOX_SERVER_NAME is longer than 64 characters."
  echo "At least one domain must be under 64 characters when using letsencrypt and certbot. The work around is to always include this short domain to each cert request: lt64.$CHILLBOX_SERVER_NAME"
  echo "Reference: https://community.letsencrypt.org/t/the-server-will-not-issue-certificates-for-the-identifier-neworder-request-did-not-include-a-san-short-enough-to-fit-in-cn/156353/14"
  exit 1
fi

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
    && [ -s "/etc/chillbox/sites/.has-certs/.$cert_name-$domain_list_hash" ]; then
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
    # shellcheck disable=SC2068
    certbot certonly \
      --user-agent-comment "chillbox/0.0" \
      --server "$ACME_SERVER" \
      --non-interactive \
      --webroot \
      --webroot-path "/srv/chillbox" \
      --cert-name "$cert_name" \
      --domain "lt64.$CHILLBOX_SERVER_NAME" \
      $@
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
    printf "%s" "$domain_list" > "/etc/chillbox/sites/.has-certs/.$cert_name-$domain_list_hash"
  fi
}

# First try to get the certs for chillbox itself and fail early. This way the
# script avoids trying to get certs for the site domains which would probably
# fail as well.

if [ "$MANAGE_DNS_RECORDS" = "true" ]; then
  chillbox_domain_list="$CHILLBOX_SERVER_NAME"
  hostname_chillbox="$(hostname).$CHILLBOX_SERVER_NAME"
  if [ "$MANAGE_HOSTNAME_DNS_RECORDS" = "true" ]; then
    chillbox_domain_list="$chillbox_domain_list $hostname_chillbox"
  fi
  get_cert chillbox "$chillbox_domain_list" \
    || (echo "ERROR $script_name: Failed to get new ssl cert for chillbox domains ($chillbox_domain_list)." && exit 1)
fi

# TODO: The no_index_hostname will only work for a single chillbox server.
no_index_hostname="$(basename "$(hostname)" "-0")"
sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname="$(basename "$site_json" .site.json)"
  if [ "$MANAGE_DNS_RECORDS" = "true" ]; then
    domain_list="$(jq -r '.domain_list[]' "$site_json")"
    if [ "$MANAGE_HOSTNAME_DNS_RECORDS" = "true" ]; then
      hostname_domain_list="$(jq -r --arg jq_hostname_chillbox "${no_index_hostname}." '.domain_list[] | $jq_hostname_chillbox + .' "$site_json")"
      domain_list="$domain_list $hostname_domain_list"
    fi
    get_cert "$slugname" "$domain_list" || continue
  fi
done
