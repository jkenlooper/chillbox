#!/usr/bin/env sh

# This script prompts for the DigitalOcean access keys and encrypts them to
# a tfvars file.  The encrypted
# tfvars file will be placed in the /var/lib/doterra directory.

set -o errexit

# Sanity check for the terraform workspace being set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

gpg_key_name="$1"
test -n "$gpg_key_name" || (echo "ERROR $0: gpg_key_name variable is empty" && exit 1)

test -d "/run/tmp/secrets" || (echo "ERROR $0: The path '/run/tmp/secrets' is not a directory" && exit 1)
secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "${secure_tmp_secrets_dir}"
chmod -R 0700 "${secure_tmp_secrets_dir}"

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
read -s -p "DigitalOcean API Access Token:
" do_token

read -s -p "DigitalOcean Spaces access key ID:
" do_spaces_access_key_id

read -s -p "DigitalOcean Spaces secret access key:
" do_spaces_secret_access_key

# Create the tf vars file that will be encrypted.
jq --null-input \
  --arg jq_do_token "$do_token" \
  --arg jq_do_spaces_access_key_id "$do_spaces_access_key_id" \
  --arg jq_do_spaces_secret_access_key "$do_spaces_secret_access_key" \
  '{
  do_token: $jq_do_token,
  do_spaces_access_key_id: $jq_do_spaces_access_key_id,
  do_spaces_secret_access_key: $jq_do_spaces_secret_access_key,
  }' > "${secure_tmp_secrets_dir}/credentials.tfvars.json"

gpg --encrypt --recipient "${gpg_key_name}" --armor --output "${encrypted_credentials_tfvars_file}" \
  --comment "Chillbox doterra credentials tfvars" \
  --comment "Terraform workspace: $WORKSPACE" \
  --comment "Date: $(date)" \
  "${secure_tmp_secrets_dir}/credentials.tfvars.json"
shred -z -u "${secure_tmp_secrets_dir}/credentials.tfvars.json"
