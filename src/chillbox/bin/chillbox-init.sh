#!/usr/bin/env sh

set -o errexit

developer_ssh_key_github_list="${DEVELOPER_SSH_KEY_GITHUB_LIST:-}"
access_key_id="${ACCESS_KEY_ID:-}"
secret_access_key="${SECRET_ACCESS_KEY:-}"
chillbox_gpg_passphrase="${CHILLBOX_GPG_PASSPHRASE:-}"
dev_user_passphrase="${DEV_USER_PASSPHRASE:-}"
tech_email="${TECH_EMAIL:-}"
immutable_bucket_name="${IMMUTABLE_BUCKET_NAME:-}"
artifact_bucket_name="${ARTIFACT_BUCKET_NAME:-}"
sites_artifact="${SITES_ARTIFACT:-}"
chillbox_artifact="${CHILLBOX_ARTIFACT:-}"
s3_endpoint_url="${S3_ENDPOINT_URL:-}"
chillbox_server_name="${CHILLBOX_SERVER_NAME:-}"
chillbox_gpg_key_name="${CHILLBOX_GPG_KEY_NAME:-}"

if [ -z "$developer_ssh_key_github_list" ]; then
  printf '\n%s\n' "No DEVELOPER_SSH_KEY_GITHUB_LIST variable set."
  printf '\n%s\n' "Enter the GitHub usernames that should have access separated by spaces."
  read -r developer_ssh_key_github_list
  test -n "$developer_ssh_key_github_list" || (echo "No usernames set. Exiting" && exit 1)
fi

if [ -z "$access_key_id" ]; then
  printf '\n%s\n' "No ACCESS_KEY_ID variable set."
  printf '\n%s\n' "Enter the access key id for the S3 object storage being used. Characters entered are hidden."
  stty -echo
  read -r access_key_id
  stty echo
  test -n "$access_key_id" || (echo "No access key id set. Exiting" && exit 1)
fi
if [ -z "$secret_access_key" ]; then
  printf '\n%s\n' "No SECRET_ACCESS_KEY variable set."
  printf '\n%s\n' "Enter the secret access key for the S3 object storage being used. Characters entered are hidden."
  stty -echo
  read -r secret_access_key
  stty echo
  test -n "$secret_access_key" || (echo "No secret access key set. Exiting" && exit 1)
fi

if [ -z "$chillbox_gpg_passphrase" ]; then
  printf '\n%s\n' "No CHILLBOX_GPG_PASSPHRASE variable set."
  printf '\n%s\n' "GPG key is created on the chillbox server; set the passphrase for it here."
  printf '\n%s\n' "Characters entered are hidden."
  stty -echo
  read -r chillbox_gpg_passphrase
  stty echo
  test -n "$chillbox_gpg_passphrase" || (echo "No chillbox gpg passphrase set. Exiting" && exit 1)
fi

if [ -z "$dev_user_passphrase" ]; then
  printf '\n%s\n' "No DEV_USER_PASSPHRASE variable set."
  printf '\n%s\n' "Enter the initial passphrase for the new 'dev' user. The dev user will be prompted to change it on the first login."
  printf '\n%s\n' "Characters entered are hidden."
  stty -echo
  read -r dev_user_passphrase
  stty echo
  test -n "$dev_user_passphrase" || (echo "No initial dev user passphrase set. Exiting" && exit 1)
fi

if [ -z "$tech_email" ]; then
  printf '\n%s\n' "No TECH_EMAIL variable set."
  printf '\n%s\n' "Enter the contact email address to use for notifications."
  read -r tech_email
  test -n "$tech_email" || (echo "No tech email set. Exiting" && exit 1)
fi

if [ -z "$immutable_bucket_name" ]; then
  printf '\n%s\n' "No IMMUTABLE_BUCKET_NAME variable set."
  printf '\n%s\n' "Enter the immutable bucket name to use."
  read -r immutable_bucket_name
  test -n "$immutable_bucket_name" || (echo "No immutable bucket name set. Exiting" && exit 1)
fi

if [ -z "$artifact_bucket_name" ]; then
  printf '\n%s\n' "No ARTIFACT_BUCKET_NAME variable set."
  printf '\n%s\n' "Enter the artifact bucket name to use."
  read -r artifact_bucket_name
  test -n "$artifact_bucket_name" || (echo "No artifact bucket name set. Exiting" && exit 1)
fi

if [ -z "$sites_artifact" ]; then
  printf '\n%s\n' "No SITES_ARTIFACT variable set."
  printf '\n%s\n' "Enter the sites artifact file to use."
  read -r sites_artifact
  test -n "$sites_artifact" || (echo "No sites artifact file set. Exiting" && exit 1)
fi

if [ -z "$chillbox_artifact" ]; then
  printf '\n%s\n' "No CHILLBOX_ARTIFACT variable set."
  printf '\n%s\n' "Enter the chillbox artifact file to use."
  read -r chillbox_artifact
  test -n "$chillbox_artifact" || (echo "No chillbox artifact file set. Exiting" && exit 1)
fi

if [ -z "$s3_endpoint_url" ]; then
  printf '\n%s\n' "No S3_ENDPOINT_URL variable set."
  printf '\n%s\n' "Enter the s3 endpoint URL to use."
  read -r s3_endpoint_url
  test -n "$s3_endpoint_url" || (echo "No s3 endpoint URL set. Exiting" && exit 1)
fi

if [ -z "$chillbox_server_name" ]; then
  printf '\n%s\n' "No CHILLBOX_SERVER_NAME variable set."
  printf '\n%s\n' "Enter the chillbox server name to use which should be a fully qualified domain name."
  read -r chillbox_server_name
  test -n "$chillbox_server_name" || (echo "No chillbox server name set. Exiting" && exit 1)
fi

if [ -z "$chillbox_gpg_key_name" ]; then
  printf '\n%s\n' "No CHILLBOX_GPG_KEY_NAME variable set."
  printf '\n%s\n' "Enter the chillbox gpg key name to use (should be unique)."
  read -r chillbox_gpg_key_name
  test -n "$chillbox_gpg_key_name" || (echo "No chillbox gpg key name set. Exiting" && exit 1)
fi

tmp_cred_csv=$(mktemp)
tmp_chillbox_artifact=$(mktemp)

cleanup() {
  echo ""
  rm -f "$tmp_chillbox_artifact"
  # Double tap
  shred -fu "$tmp_cred_csv" 2> /dev/null || rm -f "$tmp_cred_csv"
}
trap cleanup EXIT

apk update
apk add sed attr grep coreutils jq

# Need to use passwd command from the shadow-utils so the password can be set to
# expire.
apk add shadow

apk add gnupg gnupg-dirmngr

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim

addgroup dev || printf "  ...ignoring addgroup dev error"
# No password is assigned (-D) initially.
adduser -G dev -D dev || printf "  ...ignoring adduser dev error"
# Assign a password via chpasswd since this is a non-interactive script.
# By default, the chpasswd will encrypt the supplied password.
printf '%s' "dev:$dev_user_passphrase" | chpasswd
# Set password as expired to force user to reset when logging in
passwd --expire dev

# A box that has been provisioned via the cloud provider should already have
# public keys added. This handles a locally provisioned box.
if [ ! -e /root/.ssh/authorized_keys ]; then
  mkdir -p /root/.ssh
  for github_username in ${developer_ssh_key_github_list}; do
    wget "https://github.com/$github_username.keys" -O - | tee -a /root/.ssh/authorized_keys
  done
  chown -R root:root /root/.ssh
  chmod -R 700 /root/.ssh
  chmod -R 644 /root/.ssh/authorized_keys
fi

# The dev user will also use the same keys as root.
mkdir -p /home/dev/.ssh
cp /root/.ssh/authorized_keys /home/dev/.ssh/
chown -R dev:dev /home/dev/.ssh
chmod -R 700 /home/dev/.ssh
chmod -R 644 /home/dev/.ssh/authorized_keys

# Use doas instead of sudo since sudo seems bloated.
apk add doas
cat <<DOAS_CONFIG > /etc/doas.d/doas.conf
permit persist dev as root
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

# IMMUTABLE_BUCKET_NAME=""
ARTIFACT_BUCKET_NAME=""
# S3_ENDPOINT_URL=""
S3_ARTIFACT_ENDPOINT_URL=""
CHILLBOX_ARTIFACT=""
# CHILLBOX_SERVER_NAME=""
# CHILLBOX_SERVER_PORT=80
# SITES_ARTIFACT=""
TECH_EMAIL=""
LETS_ENCRYPT_SERVER=""
cat <<ENVFILE > /home/dev/.env
export AWS_PROFILE=chillbox_object_storage
export IMMUTABLE_BUCKET_NAME="${immutable_bucket_name}"
export ARTIFACT_BUCKET_NAME="${artifact_bucket_name}"
export S3_ENDPOINT_URL="${s3_endpoint_url}"
export S3_ARTIFACT_ENDPOINT_URL="${s3_endpoint_url}"
export CHILLBOX_ARTIFACT="${chillbox_artifact}"
export CHILLBOX_SERVER_NAME="${chillbox_server_name}"
export CHILLBOX_GPG_KEY_NAME="${chillbox_gpg_key_name}"
export CHILLBOX_SERVER_PORT=80
export SITES_ARTIFACT="${sites_artifact}"
export TECH_EMAIL="${tech_email}"
# TODO: switch to production version for letsencrypt server
#export LETS_ENCRYPT_SERVER="letsencrypt"
export LETS_ENCRYPT_SERVER="letsencrypt_test"
ENVFILE
chown dev:dev /home/dev/.env
chmod 600 /home/dev/.env
# shellcheck disable=SC1091
. /home/dev/.env

## RUN TEMP_AWS_CLI
# Only need aws s3 to get the chillbox artifact. Will use the
# bin/install-aws-cli.sh to install latest aws version.
has_aws="$(command -v aws || printf '')"
if [ -z "$has_aws" ]; then
  apk add \
    -q --no-progress \
    aws-cli
fi

# Set the AWS credentials so upload-artifacts.sh can use them.
cat <<HERE > "$tmp_cred_csv"
User Name, Access Key ID, Secret Access Key
chillbox_object_storage,${access_key_id},${secret_access_key}
HERE
aws configure import --csv "file://$tmp_cred_csv"
export AWS_PROFILE=chillbox_object_storage
# Don't need this temporary file anymore after the import.
shred -fu "$tmp_cred_csv" 2> /dev/null

## COPY_chillbox_artifact
aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp "s3://$ARTIFACT_BUCKET_NAME/chillbox/$CHILLBOX_ARTIFACT" \
  "$tmp_chillbox_artifact"
apk del aws-cli || printf '\n%s\n' "...Ignoring error with 'apk del aws-cli'"

# nginx/templates/ -> /etc/chillbox/templates/
mkdir -p /etc/chillbox
tar x -z -f "$tmp_chillbox_artifact" -C /etc/chillbox --strip-components 1 nginx/templates

# bin/ -> /etc/chillbox/bin/
mkdir -p /etc/chillbox/bin
tar x -z -f "$tmp_chillbox_artifact" -C /etc/chillbox/bin --strip-components 1 bin

## RUN_INSTALL_SCRIPTS
/etc/chillbox/bin/install-aws-cli.sh
/etc/chillbox/bin/install-chill.sh
/etc/chillbox/bin/install-service-dependencies.sh
/etc/chillbox/bin/install-acme.sh "$LETS_ENCRYPT_SERVER" "$TECH_EMAIL"

 CHILLBOX_GPG_KEY_NAME="${chillbox_gpg_key_name}" \
 CHILLBOX_GPG_PASSPHRASE="${chillbox_gpg_passphrase}" \
   /etc/chillbox/bin/generate-chillbox-key.sh

## RUN_CHILLBOX_ENV_NAMES
/etc/chillbox/bin/create-env_names-file.sh

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

## RUN DEV_USER
chown dev /etc/chillbox/env_names

## acme.sh certs
/etc/chillbox/bin/issue-and-install-letsencrypt-certs.sh "$LETS_ENCRYPT_SERVER" || echo "ERROR (ignored): Failed to run issue-and-install-letsencrypt-certs.sh"

nginx -t
rc-update add nginx default
rc-service nginx start
