#!/usr/bin/env sh

set -o errexit

WORKSPACE="${WORKSPACE:-}"
secure_tmp_secrets_dir="${secure_tmp_secrets_dir:-}"

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "This command is not supported when using $0 script."
  exit 1
fi

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
test -n "$secure_tmp_secrets_dir" || (echo "ERROR: secure_tmp_secrets_dir variable is empty." && exit 1)

encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc
decrypted_credentials_tfvars_file="${secure_tmp_secrets_dir}/credentials.tfvars.json"
if [ ! -f "${decrypted_credentials_tfvars_file}" ]; then
  echo "INFO $0: Decrypting file '${encrypted_credentials_tfvars_file}' to '${decrypted_credentials_tfvars_file}'"
  gpg --quiet --decrypt "${encrypted_credentials_tfvars_file}" > "${decrypted_credentials_tfvars_file}"
fi

cd /usr/local/src/chillbox-terraform

terraform workspace select "$WORKSPACE" || \
  terraform workspace new "$WORKSPACE"

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "Sanity check to make sure workspace selected matches environment has failed." && exit 1)

create_output_json() {
  terraform output -json > /var/lib/terraform-010-infra/output.json
}
trap create_output_json EXIT

terraform \
  "$terraform_command" \
  -var-file="${decrypted_credentials_tfvars_file}"
