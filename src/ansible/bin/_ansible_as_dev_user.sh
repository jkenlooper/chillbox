#!/usr/bin/env sh

set -o errexit

plaintext_ansible_private_ssh_key_file="${plaintext_ansible_private_ssh_key_file:-}"

ansible_command=$*
test -n "$ansible_command" || (echo "ERROR $0: No args passed in. These should be the ansible command args." && exit 1)

# Sanity check that these were set.
test -n "$plaintext_ansible_private_ssh_key_file" || (echo "ERROR $0: plaintext_ansible_private_ssh_key_file variable is empty." && exit 1)
test -e "$plaintext_ansible_private_ssh_key_file" || (echo "ERROR $0: The decrypted private ssh key file at $plaintext_ansible_private_ssh_key_file does not exist." && exit 1)

cd /usr/local/src/chillbox-ansible

set -x
ansible "$@"
set +x
