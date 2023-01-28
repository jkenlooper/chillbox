#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

output_file="$1"
test -n "$output_file" || (echo "ERROR $script_name: output file path is blank." && exit 1)

secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"

secure_tmp_tfstate_dir=/usr/local/src/chillbox-terraform/terraform.tfstate.d
mkdir -p "$secure_tmp_tfstate_dir"
chown -R dev:dev "$secure_tmp_tfstate_dir"
chmod -R 0700 "$secure_tmp_tfstate_dir"

data_volume_terraform_010_infra=/var/lib/terraform-010-infra
mkdir -p "$data_volume_terraform_010_infra"
chown -R dev:dev "$data_volume_terraform_010_infra"
chmod -R 0700 "$data_volume_terraform_010_infra"

output_file_name="$(basename "$output_file")"
tmp_output_file="/run/tmp/secrets/chillbox-terraform-state-tmp-output/$output_file_name"
mkdir -p "$(dirname "$tmp_output_file")"
chown -R dev:dev "$(dirname "$tmp_output_file")"
chmod -R 0700 "$(dirname "$tmp_output_file")"


if [ ! -e "$ENCRYPTED_TFSTATE" ]; then
  echo "INFO $script_name: No encrypted tfstate file ($ENCRYPTED_TFSTATE) exists to pull."
  exit 0
fi

echo "INFO $script_name: Executing _init_tfstate_with_push.sh"
_init_tfstate_with_push.sh

su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  _doterra_state_pull_as_dev_user.sh '$tmp_output_file'"

cp "$tmp_output_file" "$output_file"
