#!/usr/bin/env sh

set -o errexit

developer_public_ssh_keys="${DEVELOPER_PUBLIC_SSH_KEYS:-}"
access_key_id="${ACCESS_KEY_ID:-}"
secret_access_key="${SECRET_ACCESS_KEY:-}"
dev_user_passphrase_hashed="${DEV_USER_PASSPHRASE_HASHED:-}"
tech_email="${TECH_EMAIL:-}"
immutable_bucket_name="${IMMUTABLE_BUCKET_NAME:-}"
immutable_bucket_domain_name="${IMMUTABLE_BUCKET_DOMAIN_NAME:-}"
artifact_bucket_name="${ARTIFACT_BUCKET_NAME:-}"
sites_artifact="${SITES_ARTIFACT:-}"
chillbox_artifact="${CHILLBOX_ARTIFACT:-}"
s3_endpoint_url="${S3_ENDPOINT_URL:-}"
chillbox_server_name="${CHILLBOX_SERVER_NAME:-}"
manage_hostname_dns_records="${MANAGE_HOSTNAME_DNS_RECORDS:-false}"
manage_dns_records="${MANAGE_DNS_RECORDS:-false}"
# TODO The environment is not currently being used for anything at this time.
environment="${ENVIRONMENT:-}"
acme_server="${ACME_SERVER:-}"
enable_certbot="${ENABLE_CERTBOT:-}"

if [ -z "$developer_public_ssh_keys" ]; then
  printf '\n%s\n' "No DEVELOPER_PUBLIC_SSH_KEYS variable set."
  printf '\n%s\n' "Enter a public ssh key that should have access."
  test -z "$INTERACTIVE" || read -r developer_public_ssh_keys
  test -n "$developer_public_ssh_keys" || (echo "No developer ssh key added. Exiting" && exit 1)
fi

if [ -z "$access_key_id" ]; then
  printf '\n%s\n' "No ACCESS_KEY_ID variable set."
  printf '\n%s\n' "Enter the access key id for the S3 object storage being used. Characters entered are hidden."
  stty -echo
  test -z "$INTERACTIVE" || read -r access_key_id
  stty echo
  test -n "$access_key_id" || (echo "No access key id set. Exiting" && exit 1)
fi
if [ -z "$secret_access_key" ]; then
  printf '\n%s\n' "No SECRET_ACCESS_KEY variable set."
  printf '\n%s\n' "Enter the secret access key for the S3 object storage being used. Characters entered are hidden."
  stty -echo
  test -z "$INTERACTIVE" || read -r secret_access_key
  stty echo
  test -n "$secret_access_key" || (echo "No secret access key set. Exiting" && exit 1)
fi

dev_user_exists="$(id -u dev 2> /dev/null)"
if [ -z "$dev_user_exists" ]; then
  if [ -z "$INTERACTIVE" ]; then
    echo "No initial dev user exists and the INTERACTIVE env var has not been set. Will not prompt to create the dev user with a password. Exiting"
    exit 1
  fi
  printf '\n%s\n' "Enter the initial passphrase for the new 'dev' user. The dev user will be prompted to change it on the first login. This passphrase will be hashed with a SHA512-based password algorithm."
  printf '\n%s\n' "Characters entered are hidden."
  tmp_file_for_hashed_pass="$(mktemp)"
  openssl passwd -6 > "$tmp_file_for_hashed_pass"
  dev_user_passphrase_hashed="$(cat "$tmp_file_for_hashed_pass")"
  rm -f "$tmp_file_for_hashed_pass"
  test -n "$dev_user_passphrase_hashed" || (echo "No initial dev user passphrase set. Exiting" && exit 1)
fi

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

if [ -z "$chillbox_artifact" ]; then
  printf '\n%s\n' "No CHILLBOX_ARTIFACT variable set."
  printf '\n%s\n' "Enter the chillbox artifact file to use."
  test -z "$INTERACTIVE" || read -r chillbox_artifact
  test -n "$chillbox_artifact" || (echo "No chillbox artifact file set. Exiting" && exit 1)
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

# TODO The environment is not currently being used for anything at this time.
# if [ -z "$environment" ]; then
#   printf '\n%s\n' "No ENVIRONMENT variable set."
#   printf '\n%s\n' "Enter the chillbox environment: development, test, acceptance, production."
#   test -z "$INTERACTIVE" || read -r environment
#   test -n "$environment" || (echo "No environment set. Exiting" && exit 1)
#   if [ "$environment" != "development" ] \
#     && [ "$environment" != "test" ] \
#     && [ "$environment" != "acceptance" ] \
#     && [ "$environment" != "production" ]; then
#     echo "The environment must be set to one of: development, test, acceptance, production."
#     exit 1
#   fi
# fi

if [ -z "$acme_server" ]; then
  printf '\n%s\n' "No ACME_SERVER variable set."
  printf '\n%s\n' "Enter the server to use when certbot is getting certificates."
  test -z "$INTERACTIVE" || read -r acme_server
  test -n "$acme_server" || (echo "No ACME server set. Exiting" && exit 1)
fi

tmp_chillbox_artifact=$(mktemp)

cleanup() {
  echo ""
  rm -f "$tmp_chillbox_artifact"
}
trap cleanup EXIT

apk update
apk upgrade
apk add sed attr grep coreutils jq entr

# Need to use passwd command from the shadow-utils so the password can be set to
# expire.
apk add shadow

apk add gnupg gnupg-dirmngr
apk add openssl

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim

# Only need to create the dev user here if this script was ran interactively and
# a hashed password has been created. Otherwise the existing dev user should
# have the password reset by expiring it.
if [ -z "$dev_user_exists" ] && [ -n "$dev_user_passphrase_hashed" ]; then
  useradd -m -U -p "$dev_user_passphrase_hashed" dev
else
  # Set password as expired to force user to reset when logging in
  passwd --expire dev
fi

# A box that has been provisioned via the cloud provider should already have
# public keys added. This handles a locally provisioned box.
if [ ! -e /root/.ssh/authorized_keys ]; then
  mkdir -p /root/.ssh
  printf '%b' "$developer_public_ssh_keys" > /root/.ssh/authorized_keys
  chown -R root:root /root/.ssh
  chmod -R 700 /root/.ssh
  chmod -R 644 /root/.ssh/authorized_keys
fi

# The dev and ansibledev users will also use the same keys as root.
mkdir -p /home/dev/.ssh
cp /root/.ssh/authorized_keys /home/dev/.ssh/
chown -R dev:dev /home/dev/.ssh
chmod -R 700 /home/dev/.ssh
chmod -R 644 /home/dev/.ssh/authorized_keys

ansibledev_user_exists="$(id -u ansibledev 2> /dev/null)"
if [ -n "$ansibledev_user_exists" ]; then
  mkdir -p /home/ansibledev/.ssh
  cp /root/.ssh/authorized_keys /home/ansibledev/.ssh/
  chown -R ansibledev:ansibledev /home/ansibledev/.ssh
  chmod -R 700 /home/ansibledev/.ssh
  chmod -R 644 /home/ansibledev/.ssh/authorized_keys
fi

# Use doas instead of sudo since sudo seems bloated.
apk add doas
# TODO configure doas for the ansibledev user

# TODO Allow ansibledev user to perform apk upgrade.
# fatal: [chillbox-ansibletest-development-0]: FAILED! => {"changed": false,
# "msg": "failed to upgrade packages", "packages": [], "stderr": "ERROR: Unable
# to lock database: Permission denied\nERROR: Failed to open apk database:
# Permission denied\n", "stderr_lines": ["ERROR: Unable to lock database:
# Permission denied", "ERROR: Failed to open apk database: Permission denied"],
# "stdout": "", "stdout_lines": []}
#
# Nov  5 13:05:52 localhost user.info ansible-community.general.apk: Invoked
# with upgrade=True state=present no_cache=False update_cache=False
# available=False world=/etc/apk/world name=None repository=None
#
#permit persist ansibledev as root cmd apk args fix
#permit persist ansibledev as root cmd apk args update
#permit persist ansibledev as root cmd apk args upgrade
#permit persist ansibledev as root cmd apk args cache
#permit persist ansibledev as root cmd reboot
#permit persist ansibledev as root cmd halt

# TODO It would be better to have the ansibledev user only have permission to
# run a few commands and not have full root access. Not sure if it is possible
# to only allow maintenance commands like apk update and such when using ansible.
mkdir -p /etc/doas.d
cat <<DOAS_CONFIG > /etc/doas.d/chillbox.doas.conf
permit persist dev as root
permit persist ansibledev as root
DOAS_CONFIG
chmod 0600 /etc/doas.d/chillbox.doas.conf
doas -C /etc/doas.d/chillbox.doas.conf && echo "doas config ok"

# Configure sshd to only allow users with authorized_keys to ssh in. The root
# user is blocked from logging in. PAM needs to be added and enabled for it to
# work with the AuthorizedKeysFile and publickey method.
apk add openssh-server-pam

cat <<SSHD_CONFIG > /etc/ssh/sshd_config
AuthenticationMethods publickey,keyboard-interactive
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication yes
KbdInteractiveAuthentication no
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
UsePAM yes
SSHD_CONFIG

sshd -t
rc-service sshd restart

## Support s6 init scripts.
# Only if not using container s6-overlay and using openrc instead.
apk add s6 s6-portable-utils
rc-update add s6-svscan boot

build_date=$(date)
cat <<ENVFILE > /home/dev/.env
# Generated by $0
# Do not edit this file.
# Do not set secrets in this file even though it should only be readable by
# 'dev' user. Secrets should be encrypted when on disk or saved as plaintext on
# a tmpfs mount.
# The sitejsonplaceholder-* values are set per *.site.json file.
export ARTIFACT_BUCKET_NAME="${artifact_bucket_name}"
export AWS_PROFILE=chillbox_object_storage
export CHILLBOX_SERVER_NAME="${chillbox_server_name}"
# TODO The environment is not currently being used for anything at this time.
# export ENVIRONMENT="${environment}"
export CHILLBOX_SERVER_PORT=80
export IMMUTABLE_BUCKET_DOMAIN_NAME="${immutable_bucket_domain_name}"
export IMMUTABLE_BUCKET_NAME="${immutable_bucket_name}"
export ACME_SERVER="${acme_server}"
export MANAGE_HOSTNAME_DNS_RECORDS="${manage_hostname_dns_records}"
export MANAGE_DNS_RECORDS="${manage_dns_records}"
export ENABLE_CERTBOT="${enable_certbot}"
export S3_ENDPOINT_URL="${s3_endpoint_url}"
export SERVER_NAME="sitejsonplaceholder-server_name"
export SERVER_PORT=80
export SLUGNAME="sitejsonplaceholder-slugname"
export TECH_EMAIL="${tech_email}"
export VERSION="sitejsonplaceholder-version"
ENVFILE
chown dev:dev /home/dev/.env
chmod 0400 /home/dev/.env

mkdir -p /etc/chillbox
chown dev:ansibledev /etc/chillbox
chmod 0770 /etc/chillbox
# Also update the template: src/ansible/playbooks/chillbox.config.jinja2
cat <<CONFIGFILE > /etc/chillbox/chillbox.config
# Initially generated by $0
# Date ${build_date}
# Updating this file should trigger a process that runs the
# /etc/chillbox/bin/update.sh script.

# These artifact files are in the ${artifact_bucket_name} s3 bucket.
# /chillbox/
export CHILLBOX_ARTIFACT="${chillbox_artifact}"
# /_sites/
export SITES_ARTIFACT="${sites_artifact}"
CONFIGFILE
chown ansibledev:chillconf /etc/chillbox/chillbox.config
chmod 0660 /etc/chillbox/chillbox.config

# Always source the chillbox.config before the .env to prevent chillbox.config
# overwriting settings that are in the .env.
# shellcheck disable=SC1091
. /etc/chillbox/chillbox.config
# shellcheck disable=SC1091
. /home/dev/.env

# Set the credentials for accessing the s3 object storage
mkdir -p /home/dev/.aws
chown -R dev:dev /home/dev/.aws
mkdir -p "$HOME/.aws"
chmod 0700 /home/dev/.aws
chmod 0700 "$HOME/.aws"
cat <<HERE > "$HOME/.aws/credentials"
[chillbox_object_storage]
aws_access_key_id=${access_key_id}
aws_secret_access_key=${secret_access_key}
HERE
chmod 0600 "$HOME/.aws/credentials"
cp "$HOME/.aws/credentials" /home/dev/.aws/credentials
chmod 0600 /home/dev/.aws/credentials
chown dev:dev /home/dev/.aws/credentials

# UPKEEP due: "2023-07-22" label: "s5cmd for s3 object storage" interval: "+6 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_checksum="379d054f434bd1fbd44c0ae43a3f0f11a25e5c23fd9d7184ceeae1065e74e94ad6fa9e42dadd32d72860b919455e22cd2100b6315fd610d8bb4cfe81474621b4"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
sha512sum "$s5cmd_tmp_dir/$s5cmd_tar"
echo "$s5cmd_checksum  $s5cmd_tmp_dir/$s5cmd_tar" | sha512sum -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_tmp_dir/$s5cmd_tar.INVALID" \
    && exit 1 \
    )
tar x -o -f "$s5cmd_tmp_dir/$s5cmd_tar" -C "/usr/local/bin" s5cmd
rm -rf "$s5cmd_tmp_dir"

## COPY_chillbox_artifact
s5cmd cp \
  "s3://$ARTIFACT_BUCKET_NAME/chillbox/$CHILLBOX_ARTIFACT" \
  "$tmp_chillbox_artifact"

# nginx/templates/ -> /etc/chillbox/templates/
tar x -z -f "$tmp_chillbox_artifact" -C /etc/chillbox --strip-components 1 nginx/templates

# bin/ -> /etc/chillbox/bin/
mkdir -p /etc/chillbox/bin
tar x -z -f "$tmp_chillbox_artifact" -C /etc/chillbox/bin --strip-components 1 bin

# dep/ -> /var/lib/chillbox/python/
mkdir -p /var/lib/chillbox/python
tar x -z -f "$tmp_chillbox_artifact" -C /var/lib/chillbox/python --strip-components 1 dep

## RUN_INSTALL_SCRIPTS
/etc/chillbox/bin/install-chill.sh
/etc/chillbox/bin/install-service-dependencies.sh
/etc/chillbox/bin/install-certbot.sh

## Compile deno scripts and install in the /etc/chillbox/bin directory.
# The deno scripts have been replaced with shell scripts that wrap around the
# openssl commands. It is no longer necessary to use make to compile the deno
# scripts at this time.
##tmp_keys_dir="$(mktemp -d)"
##tar x -z -f "$tmp_chillbox_artifact" -C "$tmp_keys_dir" --strip-components 1 keys
##HOME=/home/dev make -C "$tmp_keys_dir"
##BINDIR=/etc/chillbox/bin make -C "$tmp_keys_dir" install

/etc/chillbox/bin/generate-chillbox-key.sh

## Setup the watcher process for chillbox.config file changes.
mkdir -p /etc/init.d
cat <<MEOW > /etc/init.d/chillbox-trigger-update
#!/sbin/openrc-run
supervisor=s6
name="chillbox-trigger-update"
procname="chillbox-trigger-update"
description="Watch the /etc/chillbox/chillbox.config file for changes and run update.sh"
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

# nginx/nginx.conf -> /etc/nginx/nginx.conf
mkdir -p /etc/nginx
tar x -z -f "$tmp_chillbox_artifact" -C /etc/nginx --strip-components 1 nginx/nginx.conf

# nginx/default.nginx.conf -> /etc/nginx/conf.d/default.nginx.conf
mkdir -p /etc/nginx/conf.d
tar x -z -f "$tmp_chillbox_artifact" -C /etc/nginx/conf.d --strip-components 1 nginx/default.nginx.conf

# nginx/chillbox.ssl_cert.include -> /etc/nginx/conf.d/chillbox.ssl_cert.include
mkdir -p /etc/nginx/conf.d
tar x -z -f "$tmp_chillbox_artifact" -C /etc/nginx/conf.d --strip-components 1 nginx/chillbox.ssl_cert.include

## RUN NGINX_CONF
/etc/chillbox/bin/init-nginx.sh

/etc/chillbox/bin/site-init.sh
/etc/chillbox/bin/reload-templates.sh

nginx -t
rc-update add nginx default
rc-service nginx start

if [ "$enable_certbot" = "true" ]; then
  mkdir -p /etc/chillbox/sites/.has-certs
  chown -R dev:dev /etc/chillbox/sites/.has-certs
  su dev -c '/etc/chillbox/bin/issue-and-install-certs.sh' || echo "WARNING: Failed to run issue-and-install-certs.sh"
  /etc/chillbox/bin/reload-templates.sh

  # Renew after issue-and-install-certs.sh in case it downloaded an almost expired
  # cert from s3 object storage. This helps prevent a gap from happening if the
  # cron job to renew doesn't happen in time.
  su dev -c "certbot renew --user-agent-comment 'chillbox/0.0' --server '$ACME_SERVER'"

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
  # letsencrypt ACME server. The dev user is used to run certbot renew commands.
  random_day_of_week="$(awk 'BEGIN{srand(); print int(rand()*7)}')"
  random_start_hour="$(awk 'BEGIN{srand(); print int(rand()*11)}')"
  echo "0 $random_start_hour * * $random_day_of_week su dev -c \"awk 'BEGIN{srand(); print int(rand()*((60*60*12)+1))}' | xargs sleep && certbot renew --server '$acme_server' --user-agent-comment 'chillbox/0.0' -q\" && nginx -t && rc-service nginx reload" \
    | tee -a /etc/crontabs/root
fi

nginx -t && rc-service nginx reload

# This script shouldn't be executed again.
chmod -x "$0"

# Create the init-date.txt file when this script has successfully run. This is
# used by ansible playbooks to prevent running the chillbox-init.sh script
# again.
date > /etc/chillbox/init-date.txt
