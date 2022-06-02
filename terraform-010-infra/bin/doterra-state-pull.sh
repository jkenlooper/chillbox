#!/usr/bin/env sh

set -o errexit

output_file="$1"
test -n "$output_file" || (echo "ERROR $0: output file path is blank." && exit 1)

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


encrypted_tfstate="/var/lib/terraform-010-infra/$WORKSPACE-terraform.tfstate.json.asc"
if [ ! -e "$encrypted_tfstate" ]; then
  echo "INFO $0: No encrypted tfstate file exists to pull."
  exit 0
fi

# Need to decrypt and push the existing tfstate before pulling it.
chown dev "$(tty)"
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  WORKSPACE=$WORKSPACE \
  _doterra_state_push_as_dev_user.sh '$tmp_output_file'"
chown root "$(tty)"

#echo "INFO $0: Decrypting file '$encrypted_tfstate' to '$tmp_output_file'"
#chown dev "$(tty)"
#su dev -c "gpg --quiet --decrypt '$encrypted_tfstate'" > "$tmp_output_file"
#chown root "$(tty)"
#
#cd /usr/local/src/chillbox-terraform
#terraform workspace select "$WORKSPACE" || \
#  terraform workspace new "$WORKSPACE"
#
## Check the existance and size of the decrypted tfstate file and push that
## first before pulling down the state.
#if [ -e "$tmp_output_file" ] && [ -s "$tmp_output_file" ]; then
#  su dev -c "terraform state push '$tmp_output_file'"
#fi



chown dev "$(tty)"
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  WORKSPACE=$WORKSPACE \
  _doterra_state_pull_as_dev_user.sh '$tmp_output_file'"
chown root "$(tty)"

cp "$tmp_output_file" "$output_file"
