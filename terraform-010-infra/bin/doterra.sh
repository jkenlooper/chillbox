#!/usr/bin/env sh

set -o errexit

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "This command is not supported when using $0 script."
  exit 1
fi


encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc
decrypted_credentials_tfvars_file=/run/tmp/secrets/doterra/credentials.tfvars.json
if [ ! -f "${decrypted_credentials_tfvars_file}" ]; then
  echo "INFO $0: Decrypting file '${encrypted_credentials_tfvars_file}' to '${decrypted_credentials_tfvars_file}'"
  test -d "/run/tmp/secrets" || (echo "ERROR $0: The path '/run/tmp/secrets' is not a directory" && exit 1)
  # TODO Verify that "/run/tmp/secrets" is also a tmpfs mount type by parsing /proc/mounts.
  secure_tmp_secrets_dir=/run/tmp/secrets/doterra
  mkdir -p "${secure_tmp_secrets_dir}"
  chmod -R 0700 "${secure_tmp_secrets_dir}"
  gpg --quiet --decrypt "${encrypted_credentials_tfvars_file}" > "${decrypted_credentials_tfvars_file}"
fi

cd /usr/local/src/chillbox-terraform

terraform workspace select $WORKSPACE || \
  terraform workspace new $WORKSPACE

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "Sanity check to make sure workspace selected matches environment has failed." && exit 1)

terraform \
  $terraform_command \
  -var-file="${decrypted_credentials_tfvars_file}"
