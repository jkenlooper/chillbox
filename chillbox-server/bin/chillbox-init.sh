#!/usr/bin/env sh

set -o errexit

if [ -e /etc/chillbox/init-date.txt ]; then
  # TODO: The chillbox-init.sh script should be idempotent.
  echo "The $0 script has already been executed."
  exit 1
fi

chillbox_owner="$(cat /var/lib/chillbox/owner)"

tech_email="${TECH_EMAIL:-}"
immutable_bucket_name="${IMMUTABLE_BUCKET_NAME:-}"
immutable_bucket_domain_name="${IMMUTABLE_BUCKET_DOMAIN_NAME:-}"
artifact_bucket_name="${ARTIFACT_BUCKET_NAME:-}"
sites_artifact="${SITES_ARTIFACT:-}"
s3_endpoint_url="${S3_ENDPOINT_URL:-}"
chillbox_server_name="${CHILLBOX_SERVER_NAME:-}"
manage_hostname_dns_records="${MANAGE_HOSTNAME_DNS_RECORDS:-false}"
manage_dns_records="${MANAGE_DNS_RECORDS:-false}"
acme_server="${ACME_SERVER:-}"
enable_certbot="${ENABLE_CERTBOT:-}"

if [ -z "$tech_email" ]; then
  printf '\n%s\n' "No TECH_EMAIL variable set."
  printf '\n%s\n' "Enter the contact email address to use for notifications."
  test -z "$INTERACTIVE" || read -r tech_email
  test -n "$tech_email" || (echo "No tech email set. Exiting" && exit 1)
fi

if [ -z "$immutable_bucket_name" ]; then
  printf '\n%s\n' "No IMMUTABLE_BUCKET_NAME variable set."
  printf '\n%s\n' "Enter the immutable bucket name to use."
  test -z "$INTERACTIVE" || read -r immutable_bucket_name
  test -n "$immutable_bucket_name" || (echo "No immutable bucket name set. Exiting" && exit 1)
fi

if [ -z "$immutable_bucket_domain_name" ]; then
  printf '\n%s\n' "No IMMUTABLE_DOMAIN_BUCKET_NAME variable set."
  printf '\n%s\n' "Enter the immutable bucket domain name to use."
  test -z "$INTERACTIVE" || read -r immutable_bucket_domain_name
  test -n "$immutable_bucket_domain_name" || (echo "No immutable bucket domain name set. Exiting" && exit 1)
fi

if [ -z "$artifact_bucket_name" ]; then
  printf '\n%s\n' "No ARTIFACT_BUCKET_NAME variable set."
  printf '\n%s\n' "Enter the artifact bucket name to use."
  test -z "$INTERACTIVE" || read -r artifact_bucket_name
  test -n "$artifact_bucket_name" || (echo "No artifact bucket name set. Exiting" && exit 1)
fi

if [ -z "$sites_artifact" ]; then
  printf '\n%s\n' "No SITES_ARTIFACT variable set."
  printf '\n%s\n' "Enter the sites artifact file to use."
  test -z "$INTERACTIVE" || read -r sites_artifact
  test -n "$sites_artifact" || (echo "No sites artifact file set. Exiting" && exit 1)
fi

if [ -z "$s3_endpoint_url" ]; then
  printf '\n%s\n' "No S3_ENDPOINT_URL variable set."
  printf '\n%s\n' "Enter the s3 endpoint URL to use."
  test -z "$INTERACTIVE" || read -r s3_endpoint_url
  test -n "$s3_endpoint_url" || (echo "No s3 endpoint URL set. Exiting" && exit 1)
fi

if [ -z "$chillbox_server_name" ]; then
  printf '\n%s\n' "No CHILLBOX_SERVER_NAME variable set."
  printf '\n%s\n' "Enter the chillbox server name to use which should be a fully qualified domain name."
  test -z "$INTERACTIVE" || read -r chillbox_server_name
  test -n "$chillbox_server_name" || (echo "No chillbox server name set. Exiting" && exit 1)
fi

if [ -z "$acme_server" ]; then
  printf '\n%s\n' "No ACME_SERVER variable set."
  printf '\n%s\n' "Enter the server to use when certbot is getting certificates."
  test -z "$INTERACTIVE" || read -r acme_server
  test -n "$acme_server" || (echo "No ACME server set. Exiting" && exit 1)
fi

cleanup() {
  echo ""
}
trap cleanup EXIT

apk update
apk add sed attr grep coreutils jq entr

apk add openssl

# Include common tools for deployment and management
apk add rsync

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim


chmod 0444 /etc/chillbox/redis/redis.conf

## RUN_INSTALL_SCRIPTS
/etc/chillbox/bin/install-s5cmd.sh
/etc/chillbox/bin/install-chill.sh
/etc/chillbox/bin/install-service-dependencies.sh
/etc/chillbox/bin/install-certbot.sh
/etc/chillbox/bin/install-redis.sh

## Setup the watcher process for chillbox-config.sh file changes.
mkdir -p /etc/init.d
cat <<MEOW > /etc/init.d/chillbox-trigger-update
#!/sbin/openrc-run
supervisor=s6
name="chillbox-trigger-update"
procname="chillbox-trigger-update"
description="Watch the /etc/profile.d/chillbox-config.sh file for changes and run update.sh"
s6_service_path=/etc/services.d/chillbox-trigger-update
depend() {
  need s6-svscan
}
MEOW
chmod +x "/etc/init.d/chillbox-trigger-update"
mkdir -p "/etc/services.d/chillbox-trigger-update"
cat <<PURR > "/etc/services.d/chillbox-trigger-update/run"
#!/usr/bin/execlineb -P
s6-setuidgid root
fdmove -c 2 1
/etc/chillbox/bin/watch-chillbox-config.sh
PURR
chmod +x "/etc/services.d/chillbox-trigger-update/run"
rc-update add "chillbox-trigger-update" default
rc-service "chillbox-trigger-update" start

## WORKDIR /usr/local/src/
mkdir -p /usr/local/src/

## RUN NGINX_CONF
/etc/chillbox/bin/init-nginx.sh

/etc/chillbox/bin/site-init.sh
/etc/chillbox/bin/reload-templates.sh

nginx -t
rc-update add nginx default
rc-service nginx start

if [ "$enable_certbot" = "true" ]; then
  mkdir -p /etc/chillbox/sites/.has-certs
  chown -R "$chillbox_owner" /etc/chillbox/sites/.has-certs
  su "$chillbox_owner" -c '/etc/chillbox/bin/issue-and-install-certs.sh' || echo "WARNING: Failed to run issue-and-install-certs.sh"
  /etc/chillbox/bin/reload-templates.sh

  # Renew after issue-and-install-certs.sh in case it downloaded an almost expired
  # cert from s3 object storage. This helps prevent a gap from happening if the
  # cron job to renew doesn't happen in time.
  su "$chillbox_owner" -c "certbot renew --user-agent-comment 'chillbox/0.0' --server '$ACME_SERVER'"

  # TODO Set a certbot renew hook to upload the renewed certs to s3 and set
  # life-cycle rule to expire them in 30 days. Add the s3 upload script to the
  # /etc/letsencrypt/renewal-hooks/deploy/ directory.
  # Environment variables available to deploy hook:
  #   RENEWED_LINEAGE will equal /etc/letsencrypt/live/$cert_name directory.
  #   RENEWED_DOMAINS will equal the $domain_list
  # https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-command-line-options
  # https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates
  # https://letsencrypt.org/docs/integration-guide/#when-to-renew

  # Set a random time that the certbot renew happens to avoid hitting limits with
  # letsencrypt ACME server. The user is used to run certbot renew commands.
  random_day_of_week="$(awk 'BEGIN{srand(); print int(rand()*7)}')"
  random_start_hour="$(awk 'BEGIN{srand(); print int(rand()*11)}')"
  echo "0 $random_start_hour * * $random_day_of_week su "$chillbox_owner" -c \"awk 'BEGIN{srand(); print int(rand()*((60*60*12)+1))}' | xargs sleep && certbot renew --server '$acme_server' --user-agent-comment 'chillbox/0.0' -q\" && nginx -t && rc-service nginx reload" \
    | tee -a /etc/crontabs/root
fi

nginx -t && rc-service nginx reload

# Create the init-date.txt file when this script has successfully run. This is
# to prevent running the chillbox-init.sh script again.
date > /etc/chillbox/init-date.txt
