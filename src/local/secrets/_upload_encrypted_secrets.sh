#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

echo "INFO $script_name: jq version: $(jq --version)"

ciphertext_terraform_010_infra_output_file=/var/lib/terraform-010-infra/output.json.asc
if [ ! -f "$ciphertext_terraform_010_infra_output_file" ]; then
  echo "ERROR $script_name: Missing file: $ciphertext_terraform_010_infra_output_file"
  exit 1
fi

# Set the SITES_ARTIFACT CHILLBOX_ARTIFACT SITES_MANIFEST vars
# shellcheck disable=SC1091
. /var/lib/chillbox-build-artifacts-vars

secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"

secure_tmp_home_aws_dir=/home/dev/.aws
mkdir -p "$secure_tmp_home_aws_dir"
chown -R dev:dev "$secure_tmp_home_aws_dir"
chmod -R 0700 "$secure_tmp_home_aws_dir"

mkdir -p /var/lib/encrypted-secrets/
chown -R dev:dev /var/lib/encrypted-secrets/
chmod -R 0777 /var/lib/encrypted-secrets/

encrypted_terraform_spaces=/var/lib/doterra/secrets/terraform_spaces.tfvars.json.asc
decrypted_terraform_spaces="${secure_tmp_secrets_dir}/terraform_spaces.tfvars.json"
if [ ! -f "${decrypted_terraform_spaces}" ]; then
  echo "INFO $script_name: Decrypting file ${encrypted_terraform_spaces} to ${decrypted_terraform_spaces}"
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"${encrypted_terraform_spaces}\" \"${decrypted_terraform_spaces}\""
fi

plaintext_terraform_010_infra_output_file="$secure_tmp_secrets_dir/terraform-010-infra-output.json"
if [ ! -f "$plaintext_terraform_010_infra_output_file" ]; then
  echo "INFO $script_name: Decrypting file $ciphertext_terraform_010_infra_output_file to $plaintext_terraform_010_infra_output_file"
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"$ciphertext_terraform_010_infra_output_file\" \"$plaintext_terraform_010_infra_output_file\""
fi

su dev -c "_upload_encrypted_secrets_as_dev_user.sh \"$decrypted_terraform_spaces\" \"$plaintext_terraform_010_infra_output_file\""
