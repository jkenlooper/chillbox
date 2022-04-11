#!/usr/bin/env sh

# This script prompts for the DigitalOcean access keys and encrypts them to
# a tfvars file.  The GPG key is created if it doesn't already exist.  The encrypted
# tfvars file will be placed in the /var/lib/doterra directory.

set -o errexit

test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

test -d "/run/tmp/secrets" || (echo "ERROR $0: The path '/run/tmp/secrets' is not a directory" && exit 1)
secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "${secure_tmp_secrets_dir}"
chmod -R 0700 "${secure_tmp_secrets_dir}"

encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc

gpg_key_name="chillbox_doterra"

# Create an encryption key if one doesn't already exist.  Set expiration to
# 'never' and use the default algorithm.
qgk_err_code=0
gpg --quick-generate-key "${gpg_key_name}" default encrypt never || qgk_err_code=$?


if [ $qgk_err_code -eq 2 -o $qgk_err_code -eq 1 -o $qgk_err_code -eq 0 ]; then
  if [ $qgk_err_code -eq 2 -o $qgk_err_code -eq 1 ]; then
    echo "INFO $0: Using existing key: ${gpg_key_name}"
  elif [ $qgk_err_code -eq 0 ]; then
    echo "INFO $0: Using new key: ${gpg_key_name}"
  else
    # Oops. Check the above conditions.
    exit 10
  fi

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
      --comment "$WORKSPACE" \
      --comment "Date: $(date)" \
      "${secure_tmp_secrets_dir}/credentials.tfvars.json"
    shred -z -u "${secure_tmp_secrets_dir}/credentials.tfvars.json"

else
  echo "ERROR $0: Failed running command: 'gpg --quick-generate-key \"${gpg_key_name}\" default encrypt never' exited with error code: $qgk_err_code"
  echo "Failed to encrypt secret."
fi

