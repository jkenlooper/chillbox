#!/usr/bin/env sh

set -o errexit

test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

gpg_key_name="chillbox_doterra__${WORKSPACE}"

# Create or reuse the gpg key and export the public gpg key.
doterra-init-gpg-key.sh "${gpg_key_name}"

# Create and encrypt the credentials.tfvars.json file
doterra-encrypt_tfvars.sh "${gpg_key_name}"

# Run the terraform init command to update or create .terraform.lock.hcl file.
terraform init
