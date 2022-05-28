#!/usr/bin/env sh

set -o errexit

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "This command is not supported when using $0 script."
  exit 1
fi


secure_tmp_secrets_dir=/run/tmp/secrets/doterra
mkdir -p "$secure_tmp_secrets_dir"
chown -R dev:dev "$(dirname "$secure_tmp_secrets_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_secrets_dir")"

secure_tmp_home_aws_dir=/home/dev/.aws
mkdir -p "$secure_tmp_home_aws_dir"
chown -R dev:dev "$secure_tmp_home_aws_dir"
chmod -R 0700 "$secure_tmp_home_aws_dir"

secure_tmp_tfstate_dir=/usr/local/src/chillbox-terraform/terraform.tfstate.d
mkdir -p "$secure_tmp_tfstate_dir"
chown -R dev:dev "$secure_tmp_tfstate_dir"
chmod -R 0700 "$secure_tmp_tfstate_dir"

data_volume_terraform_020_chillbox=/var/lib/terraform-020-chillbox
mkdir -p "$data_volume_terraform_020_chillbox"
chown -R dev:dev "$data_volume_terraform_020_chillbox"
chmod -R 0700 "$data_volume_terraform_020_chillbox"

decrypted_tfstate="/run/tmp/secrets/doterra/$WORKSPACE-terraform.tfstate.json"

# TODO rm encrypted file first to avoid serial conflicts?

push_pull_tfstate() {
  chown dev "$(tty)"
  su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
    WORKSPACE=$WORKSPACE \
    _doterra_state_pull_as_dev_user.sh '$decrypted_tfstate'"
  chown root "$(tty)"
}
push_pull_tfstate
trap push_pull_tfstate EXIT

chown dev "$(tty)"
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  WORKSPACE=$WORKSPACE \
  _doterra_as_dev_user.sh '$terraform_command'"
chown root "$(tty)"
