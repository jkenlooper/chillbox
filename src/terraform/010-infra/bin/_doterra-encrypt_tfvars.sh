#!/usr/bin/env sh

# This script prompts for the DigitalOcean access keys and other secrets. These
# secrets are encrypted to tfvars json file.  The encrypted tfvars file will be
# placed in the /var/lib/doterra/secrets/ directory.

set -o errexit

secure_tmp_secrets_dir="${secure_tmp_secrets_dir:-}"

# Sanity check that these were set.
test -n "$GPG_KEY_NAME" || (echo "ERROR $0: GPG_KEY_NAME variable is empty" && exit 1)
test -n "$secure_tmp_secrets_dir" || (echo "ERROR: secure_tmp_secrets_dir variable is empty." && exit 1)
ls -al "$secure_tmp_secrets_dir"
test -d "$secure_tmp_secrets_dir" || (echo "ERROR $0: The path '$secure_tmp_secrets_dir' is not a directory" && exit 1)

encrypted_do_token=/var/lib/doterra/secrets/do_token.tfvars.json.asc
encrypted_terraform_spaces=/var/lib/doterra/secrets/terraform_spaces.tfvars.json.asc
encrypted_chillbox_spaces=/var/lib/doterra/secrets/chillbox_spaces.tfvars.json.asc
encrypted_chillbox_gpg_passphrase=/var/lib/doterra/secrets/chillbox_gpg_passphrase.tfvars.json.asc

if [ -f "${encrypted_do_token}" ] && [ -f "${encrypted_terraform_spaces}" ] && [ -f "${encrypted_chillbox_spaces}" ] && [ -f "${encrypted_chillbox_gpg_passphrase}" ]; then
  echo "INFO $0: The encrypted secrets already exist at /var/lib/doterra/secrets/. Skipping the creation of a new files."
fi

cleanup() {
  echo "INFO $0: Clean up and remove the files '${secure_tmp_secrets_dir}/secrets/*.tfvars.json'."
  for secret_tfvars_json in "${secure_tmp_secrets_dir}"/secrets/*.tfvars.json; do
    if [ -e "$secret_tfvars_json" ]; then
      # Fallback on rm command if shred fails.
      shred -z -u "$secret_tfvars_json" || rm -f "$secret_tfvars_json"
    fi
  done
}
trap cleanup EXIT

mkdir -p "$(dirname "$encrypted_do_token")"
mkdir -p "$(dirname "$encrypted_terraform_spaces")"
mkdir -p "$(dirname "$encrypted_chillbox_spaces")"
mkdir -p "$(dirname "$encrypted_chillbox_gpg_passphrase")"

echo "Enter secrets that will be encrypted to the /var/lib/doterra/secrets/ directory."
echo "Characters entered are not shown."

if [ -f "${encrypted_do_token}" ]; then
  echo "INFO $0: The '${encrypted_do_token}' file already exists. Skipping the creation of a new one."
else
  printf '\n%s\n' "DigitalOcean API Access Token for Terraform to use:"
  stty -echo
  read -r do_token
  stty echo
  secret_tfvars_json="${secure_tmp_secrets_dir}/secrets/do_token.tfvars.json"
  mkdir -p "$(dirname "$secret_tfvars_json")"
  jq --null-input \
    --arg jq_do_token "$do_token" \
    '{
    do_token: $jq_do_token,
    }' > "$secret_tfvars_json"
  gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "${encrypted_do_token}" \
    --comment "Chillbox doterra secrets do_token tfvars" \
    --comment "Date: $(date)" \
    "$secret_tfvars_json"
  shred -z -u "$secret_tfvars_json" || rm -f "$secret_tfvars_json"
fi

if [ -f "${encrypted_terraform_spaces}" ]; then
  echo "INFO $0: The '${encrypted_terraform_spaces}' file already exists. Skipping the creation of a new one."
else
  printf '\n%s\n' "DigitalOcean Spaces access key ID for Terraform to use:"
  stty -echo
  read -r do_spaces_access_key_id
  stty echo
  printf '\n%s\n' "DigitalOcean Spaces secret access key for Terraform to use:"
  stty -echo
  read -r do_spaces_secret_access_key
  stty echo
  secret_tfvars_json="${secure_tmp_secrets_dir}/secrets/terraform_spaces.tfvars.json"
  mkdir -p "$(dirname "$secret_tfvars_json")"
  jq --null-input \
  --arg jq_do_spaces_access_key_id "$do_spaces_access_key_id" \
  --arg jq_do_spaces_secret_access_key "$do_spaces_secret_access_key" \
    '{
      do_spaces_access_key_id: $jq_do_spaces_access_key_id,
      do_spaces_secret_access_key: $jq_do_spaces_secret_access_key,
    }' > "$secret_tfvars_json"
  gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "${encrypted_terraform_spaces}" \
    --comment "Chillbox doterra secrets terraform_spaces tfvars" \
    --comment "Date: $(date)" \
    "$secret_tfvars_json"
  shred -z -u "$secret_tfvars_json" || rm -f "$secret_tfvars_json"
fi

if [ -f "${encrypted_chillbox_spaces}" ]; then
  echo "INFO $0: The '${encrypted_chillbox_spaces}' file already exists. Skipping the creation of a new one."
else
  printf '\n%s\n' "DigitalOcean Spaces access key ID for chillbox server to use:"
  stty -echo
  read -r do_chillbox_spaces_access_key_id
  stty echo
  printf '\n%s\n' "DigitalOcean Spaces secret access key for chillbox server to use:"
  stty -echo
  read -r do_chillbox_spaces_secret_access_key
  stty echo
  secret_tfvars_json="${secure_tmp_secrets_dir}/secrets/chillbox_spaces.tfvars.json"
  mkdir -p "$(dirname "$secret_tfvars_json")"
  jq --null-input \
    --arg jq_do_chillbox_spaces_access_key_id "$do_chillbox_spaces_access_key_id" \
    --arg jq_do_chillbox_spaces_secret_access_key "$do_chillbox_spaces_secret_access_key" \
    '{
      do_chillbox_spaces_access_key_id: $jq_do_chillbox_spaces_access_key_id,
      do_chillbox_spaces_secret_access_key: $jq_do_chillbox_spaces_secret_access_key,
    }' > "$secret_tfvars_json"
  gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "${encrypted_chillbox_spaces}" \
    --comment "Chillbox doterra secrets chillbox_spaces tfvars" \
    --comment "Date: $(date)" \
    "$secret_tfvars_json"
  shred -z -u "$secret_tfvars_json" || rm -f "$secret_tfvars_json"
fi

if [ -f "${encrypted_chillbox_gpg_passphrase}" ]; then
  echo "INFO $0: The '${encrypted_chillbox_gpg_passphrase}' file already exists. Skipping the creation of a new one."
else
  printf '\n%s\n' "Passphrase for new gpg key for chillbox server to use:"
  stty -echo
  read -r chillbox_gpg_passphrase
  stty echo
  secret_tfvars_json="${secure_tmp_secrets_dir}/secrets/chillbox_gpg_passphrase.tfvars.json"
  mkdir -p "$(dirname "$secret_tfvars_json")"
  jq --null-input \
    --arg jq_chillbox_gpg_passphrase "$chillbox_gpg_passphrase" \
    '{
      chillbox_gpg_passphrase: $jq_chillbox_gpg_passphrase,
    }' > "$secret_tfvars_json"
  gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "${encrypted_chillbox_gpg_passphrase}" \
    --comment "Chillbox doterra secrets chillbox_gpg_passphrase tfvars" \
    --comment "Date: $(date)" \
    "$secret_tfvars_json"
  shred -z -u "$secret_tfvars_json" || rm -f "$secret_tfvars_json"
fi
