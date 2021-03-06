#!/usr/bin/env sh

set -o errexit

set -x
_dev_tty.sh "GPG_KEY_NAME=$GPG_KEY_NAME _doterra-init-gpg-key.sh"
set +x

# Create and encrypt the credentials.tfvars.json file
secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"
set -x
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  GPG_KEY_NAME=$GPG_KEY_NAME \
  _doterra-encrypt_tfvars.sh"
set +x

# Run the terraform init command to update or create .terraform.lock.hcl file.
set -x
su dev -c "terraform init"
set +x
