#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

secure_tmp_ansible="${secure_tmp_ansible:-}"

# Sanity check that these were set.
test -n "$GPG_KEY_NAME" || (echo "ERROR $0: GPG_KEY_NAME variable is empty" && exit 1)
test -n "$secure_tmp_ansible" || (echo "ERROR: secure_tmp_ansible variable is empty." && exit 1)
test -d "$secure_tmp_ansible" || (echo "ERROR $0: The path '$secure_tmp_ansible' is not a directory" && exit 1)

ciphertext_ansible_ssh_key=/var/lib/doterra/secrets/ansible.pem.asc
public_ansible_ssh_key=/var/lib/doterra/secrets/ansible.pem.pub
plaintext_ansible_ssh_key="$secure_tmp_ansible/ansible.pem"

if [ -f "$ciphertext_ansible_ssh_key" ]; then
  echo "INFO $script_name: The encrypted ssh key for ansible already exists. Skipping the creation of a new one."
fi

remove_plaintext_ssh_key() {
  shred -z -u "$plaintext_ansible_ssh_key" || rm -f "$plaintext_ansible_ssh_key"
}

cleanup() {
  # In case something failed and the private ssh key was not immediately encrypted after it was generated.
  if [ -e "$plaintext_ansible_ssh_key" ]; then
    echo "INFO $script_name: Removing the generated ssh key: $plaintext_ansible_ssh_key"
    remove_plaintext_ssh_key
  fi
}
trap cleanup EXIT

mkdir -p "$(dirname "$ciphertext_ansible_ssh_key")"

# No passphrase is set (-N "") since this private key will be encrypted and then
# used programatically with the ansible container. This way ansible won't need
# to use ssh-agent to use the key.
ssh-keygen -t rsa -b 4096 \
  -C "dev@local-ansible-container" \
  -N "" \
  -m "PEM" \
  -f "$plaintext_ansible_ssh_key"

gpg --encrypt --recipient "$GPG_KEY_NAME" --armor --output "$ciphertext_ansible_ssh_key" \
  --comment "Chillbox doterra secrets private ssh key for ansible" \
  --comment "Date: $(date)" \
  "$plaintext_ansible_ssh_key"
remove_plaintext_ssh_key

mv "$plaintext_ansible_ssh_key.pub" "$public_ansible_ssh_key"
