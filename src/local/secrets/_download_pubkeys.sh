#!/usr/bin/env sh

set -o errexit

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

encrypted_terraform_spaces=/var/lib/doterra/secrets/terraform_spaces.tfvars.json.asc
decrypted_terraform_spaces="${secure_tmp_secrets_dir}/terraform_spaces.tfvars.json"
if [ ! -f "${decrypted_terraform_spaces}" ]; then
  echo "INFO $0: Decrypting file ${encrypted_terraform_spaces} to ${decrypted_terraform_spaces}"
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"${encrypted_terraform_spaces}\" \"${decrypted_terraform_spaces}\""
  set +x
fi

su dev -c "_download_pubkeys_as_dev_user.sh \"$decrypted_terraform_spaces\""
