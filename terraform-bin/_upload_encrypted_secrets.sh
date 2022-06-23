#!/usr/bin/env sh

set -o errexit

echo "INFO $0: aws-cli version: $(aws --version)"
echo "INFO $0: jq version: $(jq --version)"

if [ ! -f "/var/lib/terraform-010-infra/output.json" ]; then
  echo "ERROR $0: Missing file: /var/lib/terraform-010-infra/output.json"
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

encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc
decrypted_credentials_tfvars_file="${secure_tmp_secrets_dir}/credentials.tfvars.json"
if [ ! -f "${decrypted_credentials_tfvars_file}" ]; then
  echo "INFO $0: Decrypting file ${encrypted_credentials_tfvars_file} to ${decrypted_credentials_tfvars_file}"
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"${encrypted_credentials_tfvars_file}\" \"${decrypted_credentials_tfvars_file}\""
  set +x
fi

su dev -c "_upload_encrypted_secrets_as_dev_user.sh \"$decrypted_credentials_tfvars_file\""
