#!/usr/bin/env sh

set -o errexit
set -o nounset

set -x
_dev_tty.sh "GPG_KEY_NAME=$GPG_KEY_NAME init-gpg-key.sh"
set +x

secure_tmp_ansible=/run/tmp/secrets/ansible
mkdir -p "$secure_tmp_ansible"
chown -R dev:dev /run/tmp/secrets
chmod -R 0700 /run/tmp/secrets
set -x
su dev -c "secure_tmp_ansible=$secure_tmp_ansible \
  GPG_KEY_NAME=$GPG_KEY_NAME \
  generate_and_encrypt_ssh_key_for_ansible.sh"
set +x

