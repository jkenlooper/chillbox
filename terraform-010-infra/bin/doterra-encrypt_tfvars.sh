#!/usr/bin/env sh

# This script prompts for the DigitalOcean access keys and encrypts them to
# a tfvars file.  The encrypted
# tfvars file will be placed in the /var/lib/doterra directory.

set -o errexit

WORKSPACE="${WORKSPACE:-}"
secure_tmp_secrets_dir="${secure_tmp_secrets_dir:-}"

# Sanity check for the terraform workspace being set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

gpg_key_name="$1"
test -n "$gpg_key_name" || (echo "ERROR $0: gpg_key_name variable is empty" && exit 1)

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
test -n "$secure_tmp_secrets_dir" || (echo "ERROR: secure_tmp_secrets_dir variable is empty." && exit 1)
ls -al "$secure_tmp_secrets_dir"
test -d "$secure_tmp_secrets_dir" || (echo "ERROR $0: The path '$secure_tmp_secrets_dir' is not a directory" && exit 1)

encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc


## Encrypt the credentials tfvars file
if [ -f "${encrypted_credentials_tfvars_file}" ]; then
  echo "INFO $0: The '${encrypted_credentials_tfvars_file}' file already exists. Skipping the creation of a new one."
  exit 0
fi

cleanup() {
  echo "INFO $0: Clean up and remove the file '${secure_tmp_secrets_dir}/credentials.tfvars.json' if exists."
  if [ -e "${secure_tmp_secrets_dir}/credentials.tfvars.json" ]; then
    # Fallback on rm command if shred fails.
    shred -z -u "${secure_tmp_secrets_dir}/credentials.tfvars.json" || rm -f "${secure_tmp_secrets_dir}/credentials.tfvars.json"
  fi
}
trap cleanup EXIT

echo "Enter DigitalOcean credentials to encrypt to the '${encrypted_credentials_tfvars_file}' file."
echo "Characters entered are not shown."
printf '\n%s\n' "DigitalOcean API Access Token for Terraform to use:"
stty -echo
read -r do_token
stty echo

printf '\n%s\n' "DigitalOcean Spaces access key ID for Terraform to use:"
stty -echo
read -r do_spaces_access_key_id
stty echo

printf '\n%s\n' "DigitalOcean Spaces secret access key for Terraform to use:"
stty -echo
read -r do_spaces_secret_access_key
stty echo

printf '\n%s\n' "DigitalOcean Spaces access key ID for chillbox server to use:"
stty -echo
read -r do_chillbox_spaces_access_key_id
stty echo

printf '\n%s\n' "DigitalOcean Spaces secret access key for chillbox server to use:"
stty -echo
read -r do_chillbox_spaces_secret_access_key
stty echo

printf '\n%s\n' "Passphrase for new gpg key for chillbox server to use:"
stty -echo
read -r chillbox_gpg_passphrase
stty echo

# Create the tf vars file that will be encrypted.
jq --null-input \
  --arg jq_do_token "$do_token" \
  --arg jq_do_spaces_access_key_id "$do_spaces_access_key_id" \
  --arg jq_do_spaces_secret_access_key "$do_spaces_secret_access_key" \
  --arg jq_do_chillbox_spaces_access_key_id "$do_chillbox_spaces_access_key_id" \
  --arg jq_do_chillbox_spaces_secret_access_key "$do_chillbox_spaces_secret_access_key" \
  --arg jq_chillbox_gpg_passphrase "$chillbox_gpg_passphrase" \
  '{
  do_token: $jq_do_token,
  do_spaces_access_key_id: $jq_do_spaces_access_key_id,
  do_spaces_secret_access_key: $jq_do_spaces_secret_access_key,
  do_chillbox_spaces_access_key_id: $jq_do_chillbox_spaces_access_key_id,
  do_chillbox_spaces_secret_access_key: $jq_do_chillbox_spaces_secret_access_key,
  chillbox_gpg_passphrase: $jq_chillbox_gpg_passphrase,
  }' > "${secure_tmp_secrets_dir}/credentials.tfvars.json"

gpg --encrypt --recipient "${gpg_key_name}" --armor --output "${encrypted_credentials_tfvars_file}" \
  --comment "Chillbox doterra credentials tfvars" \
  --comment "Terraform workspace: $WORKSPACE" \
  --comment "Date: $(date)" \
  "${secure_tmp_secrets_dir}/credentials.tfvars.json"
shred -z -u "${secure_tmp_secrets_dir}/credentials.tfvars.json"
