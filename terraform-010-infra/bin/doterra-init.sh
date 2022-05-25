#!/usr/bin/env sh

set -o errexit

test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

gpg_key_name="chillbox_doterra__${WORKSPACE}"


# Need to chown the tty before generating the gpg key since the user is being
# switched and gnupg pinentry requires the same permission.
# Create or reuse the gpg key and export the public gpg key.
chown dev "$(tty)"
su dev -c "WORKSPACE=$WORKSPACE \
  doterra-init-gpg-key.sh '${gpg_key_name}'"
chown root "$(tty)"


# Create and encrypt the credentials.tfvars.json file
secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  WORKSPACE=$WORKSPACE \
  doterra-encrypt_tfvars.sh '$gpg_key_name'"

# Run the terraform init command to update or create .terraform.lock.hcl file.
su dev -c "terraform init"
