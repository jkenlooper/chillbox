#!/usr/bin/env sh

set -o errexit
set -o nounset

secure_tmp_secrets_dir="${secure_tmp_secrets_dir:-}"

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "This command is not supported when using $0 script."
  exit 1
fi

terraform_output_file="$2"
terraform_output_name="$(basename "$terraform_output_file" ".asc")"
tmp_terraform_output_file="$secure_tmp_secrets_dir/$terraform_output_name"

# Sanity check that these were set.
test -n "$secure_tmp_secrets_dir" || (echo "ERROR $0: secure_tmp_secrets_dir variable is empty." && exit 1)
test -n "$terraform_output_file" || (echo "ERROR $0: second arg should be the terraform output file path and should not be empty." && exit 1)
touch "$terraform_output_file" || (echo "ERROR $0: Failed to touch '$terraform_output_file' file." && exit 1)
touch "$tmp_terraform_output_file" || (echo "ERROR $0: Failed to touch '$tmp_terraform_output_file' file." && exit 1)

decrypted_do_token="${secure_tmp_secrets_dir}/do_token.tfvars.json"
test -e "$decrypted_do_token" || (echo "ERROR $0: The decrypted secrets file at $decrypted_do_token does not exist." && exit 1)
decrypted_terraform_spaces="${secure_tmp_secrets_dir}/terraform_spaces.tfvars.json"
test -e "$decrypted_terraform_spaces" || (echo "ERROR $0: The decrypted secrets file at $decrypted_terraform_spaces does not exist." && exit 1)
decrypted_chillbox_spaces="${secure_tmp_secrets_dir}/chillbox_spaces.tfvars.json"
test -e "$decrypted_chillbox_spaces" || (echo "ERROR $0: The decrypted secrets file at $decrypted_chillbox_spaces does not exist." && exit 1)

cd /usr/local/src/chillbox-terraform

create_output_json() {
  terraform output -json > "$tmp_terraform_output_file"
  _encrypt_file_as_dev_user.sh "$terraform_output_file" "$tmp_terraform_output_file"
  shred -f -u -z "$tmp_terraform_output_file" || rm -f "$tmp_terraform_output_file"
}
trap create_output_json EXIT

terraform \
  "$terraform_command" \
  -var-file="${decrypted_do_token}" \
  -var-file="${decrypted_terraform_spaces}" \
  -var-file="${decrypted_chillbox_spaces}"
