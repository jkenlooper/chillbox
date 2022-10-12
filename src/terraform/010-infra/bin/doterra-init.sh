#!/usr/bin/env sh

set -o errexit

set -x
_dev_tty.sh "GPG_KEY_NAME=$GPG_KEY_NAME _doterra-init-gpg-key.sh"
set +x

# Create and encrypt the secrets/*.tfvars.json files
secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"
set -x
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  GPG_KEY_NAME=$GPG_KEY_NAME \
  _doterra-encrypt_tfvars.sh"
set +x

secure_tmp_ansible=/run/tmp/secrets/ansible
mkdir -p "$secure_tmp_ansible"
chown -R dev:dev "$secure_tmp_ansible"
chmod -R 0700 "$secure_tmp_ansible"
set -x
su dev -c "secure_tmp_ansible=$secure_tmp_ansible \
  GPG_KEY_NAME=$GPG_KEY_NAME \
  _doterra-generate_and_encrypt_ssh_key_for_ansible.sh"
set +x

# Run the terraform init command to update or create .terraform.lock.hcl file.
set -x
su dev -c "terraform init"
set +x
