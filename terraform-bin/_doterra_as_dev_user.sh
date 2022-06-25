#!/usr/bin/env sh

set -o errexit

secure_tmp_secrets_dir="${secure_tmp_secrets_dir:-}"

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "This command is not supported when using $0 script."
  exit 1
fi

terraform_output_file="$2"

# Sanity check that these were set.
test -n "$secure_tmp_secrets_dir" || (echo "ERROR $0: secure_tmp_secrets_dir variable is empty." && exit 1)
test -n "$terraform_output_file" || (echo "ERROR $0: second arg should be the terraform output file path and should not be empty." && exit 1)
touch "$terraform_output_file" || (echo "ERROR $0: Failed to touch '$terraform_output_file' file." && exit 1)

decrypted_credentials_tfvars_file="${secure_tmp_secrets_dir}/credentials.tfvars.json"
test -e "$decrypted_credentials_tfvars_file" || (echo "ERROR $0: The decrypted credentials file at $decrypted_credentials_tfvars_file does not exist." && exit 1)

cd /usr/local/src/chillbox-terraform

create_output_json() {
  terraform output -json > "$terraform_output_file"
}
trap create_output_json EXIT

terraform \
  "$terraform_command" \
  -var-file="${decrypted_credentials_tfvars_file}"
