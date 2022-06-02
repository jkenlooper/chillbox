#!/usr/bin/env sh

set -o errexit

set -x
_terraform_workspace_check.sh
set +x

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "ERROR $0: This command ($terraform_command) is not supported in this script."
  exit 1
fi


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

decrypted_tfstate="$secure_tmp_secrets_dir/$WORKSPACE-terraform.tfstate.json"
encrypted_tfstate="/var/lib/terraform-010-infra/$WORKSPACE-terraform.tfstate.json.asc"

# Only push the tfstate initially if it hasn't already been decrypted.
if [ -e "$encrypted_tfstate" ] && [ ! -e "$decrypted_tfstate" ]; then
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh '$encrypted_tfstate' '$decrypted_tfstate'"
  set +x

  if [ -s "$decrypted_tfstate" ]; then
    set -x
    su dev -c "
      WORKSPACE=$WORKSPACE \
        _doterra_state_push_as_dev_user.sh '$decrypted_tfstate'"
    set +x
  fi
fi

sync_encrypted_tfstate() {
  set -x
  su dev -c "
    WORKSPACE=$WORKSPACE \
    _doterra_state_pull_as_dev_user.sh '$decrypted_tfstate'"

  _dev_tty.sh "
    gpg_key_name=$gpg_key_name \
    WORKSPACE=$WORKSPACE \
    _encrypt_file_as_dev_user.sh '$encrypted_tfstate' '$decrypted_tfstate'"
  set +x
}


encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc
decrypted_credentials_tfvars_file="${secure_tmp_secrets_dir}/credentials.tfvars.json"
if [ ! -f "${decrypted_credentials_tfvars_file}" ]; then
  echo "INFO $0: Decrypting file '${encrypted_credentials_tfvars_file}' to '${decrypted_credentials_tfvars_file}'"
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh '${encrypted_credentials_tfvars_file}' '${decrypted_credentials_tfvars_file}'"
  set +x
fi

su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  WORKSPACE=$WORKSPACE \
  _doterra_as_dev_user.sh '$terraform_command' '/var/lib/terraform-010-infra/output.json'"

# Need to update the encrypted tfstate with any potential changes that have
# happened.
sync_encrypted_tfstate
