#!/usr/bin/env sh

set -o errexit

input_file="$1"
test -n "$input_file" || (echo "ERROR $0: input file path is blank." && exit 1)
test -s "$input_file" || (echo "ERROR $0: input file is missing or empty." && exit 1)

secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"

secure_tmp_tfstate_dir=/usr/local/src/chillbox-terraform/terraform.tfstate.d
mkdir -p "$secure_tmp_tfstate_dir"
chown -R dev:dev "$secure_tmp_tfstate_dir"
chmod -R 0700 "$secure_tmp_tfstate_dir"

data_volume_terraform_020_chillbox=/var/lib/terraform-020-chillbox
mkdir -p "$data_volume_terraform_020_chillbox"
chown -R dev:dev "$data_volume_terraform_020_chillbox"
chmod -R 0700 "$data_volume_terraform_020_chillbox"

input_file_name="$(basename "$input_file")"
tmp_input_file="/run/tmp/secrets/chillbox-terraform-state-tmp-input/$input_file_name"
mkdir -p "$(dirname "$tmp_input_file")"
chown -R dev:dev "$(dirname "$tmp_input_file")"
chmod -R 0700 "$(dirname "$tmp_input_file")"

cp "$input_file" "$tmp_input_file"

su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  _doterra_state_push_as_dev_user.sh '$tmp_input_file'"
