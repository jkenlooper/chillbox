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

tmp_chillbox_artifact=$(mktemp)

cleanup() {
  echo ""
  rm -f "$tmp_chillbox_artifact"
}
trap cleanup EXIT

apk update
apk upgrade
apk add sed attr grep coreutils jq

# Need to use passwd command from the shadow-utils so the password can be set to
# expire.
apk add shadow

apk add gnupg gnupg-dirmngr

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
cat <<DOAS_CONFIG > /etc/doas.conf
permit persist dev as root
permit persist ansibledev as root
DOAS_CONFIG
doas -C /etc/doas.conf && echo "doas config ok"

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

# TODO: switch to production version for letsencrypt server
#export LETS_ENCRYPT_SERVER="letsencrypt"
cat <<ENVFILE > /home/dev/.env
# Generated by $0
# The sitejsonplaceholder-* values are set per *.site.json file.
export ARTIFACT_BUCKET_NAME="${artifact_bucket_name}"
export AWS_PROFILE=chillbox_object_storage
export CHILLBOX_ARTIFACT="${chillbox_artifact}"
export CHILLBOX_SERVER_NAME="${chillbox_server_name}"
export CHILLBOX_SERVER_PORT=80
export IMMUTABLE_BUCKET_DOMAIN_NAME="${immutable_bucket_domain_name}"
export IMMUTABLE_BUCKET_NAME="${immutable_bucket_name}"
export LETS_ENCRYPT_SERVER="letsencrypt_test"
export S3_ENDPOINT_URL="${s3_endpoint_url}"
export SERVER_NAME="sitejsonplaceholder-server_name"
export SERVER_PORT=80
export SITES_ARTIFACT="${sites_artifact}"
export SLUGNAME="sitejsonplaceholder-slugname"
export TECH_EMAIL="${tech_email}"
export VERSION="sitejsonplaceholder-version"
ENVFILE
chown dev:dev /home/dev/.env
chmod 600 /home/dev/.env
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

#export AWS_PROFILE=chillbox_object_storage
#export S3_ENDPOINT_URL="${s3_endpoint_url}"

# UPKEEP due: "2023-01-01" label: "s5cmd for s3 object storage" interval: "+3 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
tar x -o -f "$s5cmd_tmp_dir/$s5cmd_tar" -C "/usr/local/bin" s5cmd
rm -rf "$s5cmd_tmp_dir"

## COPY_chillbox_artifact
s5cmd cp \
  "s3://$ARTIFACT_BUCKET_NAME/chillbox/$CHILLBOX_ARTIFACT" \
  "$tmp_chillbox_artifact"

# nginx/templates/ -> /etc/chillbox/templates/
mkdir -p /etc/chillbox
tar x -z -f "$tmp_chillbox_artifact" -C /etc/chillbox --strip-components 1 nginx/templates

# bin/ -> /etc/chillbox/bin/
mkdir -p /etc/chillbox/bin
tar x -z -f "$tmp_chillbox_artifact" -C /etc/chillbox/bin --strip-components 1 bin

## RUN_INSTALL_SCRIPTS
/etc/chillbox/bin/install-chill.sh
/etc/chillbox/bin/install-service-dependencies.sh
/etc/chillbox/bin/install-acme.sh

## Compile deno scripts and install in the /etc/chillbox/bin directory.
# The deno scripts have been replaced with shell scripts that wrap around the
# openssl commands. It is no longer necessary to use make to compile the deno
# scripts at this time.
##tmp_keys_dir="$(mktemp -d)"
##tar x -z -f "$tmp_chillbox_artifact" -C "$tmp_keys_dir" --strip-components 1 keys
##HOME=/home/dev make -C "$tmp_keys_dir"
##BINDIR=/etc/chillbox/bin make -C "$tmp_keys_dir" install

/etc/chillbox/bin/generate-chillbox-key.sh

## WORKDIR /usr/local/src/
mkdir -p /usr/local/src/

# nginx/nginx.conf -> /etc/nginx/nginx.conf
mkdir -p /etc/nginx
tar x -z -f "$tmp_chillbox_artifact" -C /etc/nginx --strip-components 1 nginx/nginx.conf

# nginx/default.nginx.conf -> /etc/nginx/conf.d/default.nginx.conf
mkdir -p /etc/nginx/conf.d
tar x -z -f "$tmp_chillbox_artifact" -C /etc/nginx/conf.d --strip-components 1 nginx/default.nginx.conf

## RUN NGINX_CONF
/etc/chillbox/bin/init-nginx.sh

/etc/chillbox/bin/site-init.sh
/etc/chillbox/bin/reload-templates.sh

## acme.sh certs
/etc/chillbox/bin/issue-and-install-letsencrypt-certs.sh || echo "ERROR (ignored): Failed to run issue-and-install-letsencrypt-certs.sh"

nginx -t
rc-update add nginx default
rc-service nginx start

# Create the init-date.txt file when this script has successfully run. This is
# used by ansible playbooks to prevent running the chillbox-init.sh script
# again.
date > /etc/chillbox/init-date.txt
