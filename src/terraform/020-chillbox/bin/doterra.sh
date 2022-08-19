#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Wrapper around the terraform command. Sets credentials needed to deploy by prompting to decrypt the credentials file if it hasn't been decrypted yet.

Usage:
  $script_name -h
  $script_name <sub-command>

Options:
  -h                  Show this help message.

Sub commands:
  plan        - Passed to the Terraform command
  apply       - Passed to the Terraform command
  destroy     - Passed to the Terraform command

HERE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

terraform_command=$1
if [ -z "$terraform_command" ]; then
  usage
  echo "ERROR $script_name: Must supply a sub command."
  exit 1
fi
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  usage
  echo "ERROR $script_name: This command ($terraform_command) is not supported in this script."
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

echo "INFO $script_name: Executing _init_tfstate_with_push.sh"
_init_tfstate_with_push.sh

encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc
decrypted_credentials_tfvars_file="${secure_tmp_secrets_dir}/credentials.tfvars.json"
if [ ! -f "${decrypted_credentials_tfvars_file}" ]; then
  echo "INFO $script_name: Decrypting file ${encrypted_credentials_tfvars_file} to ${decrypted_credentials_tfvars_file}"
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"${encrypted_credentials_tfvars_file}\" \"${decrypted_credentials_tfvars_file}\""
  set +x
fi

su dev -c "
_upload_artifacts_as_dev_user.sh \"$terraform_command\" \"$decrypted_credentials_tfvars_file\"
"

# Need to update the encrypted tfstate with any potential changes that have
# happened when the script exits.
sync_encrypted_tfstate() {
  set -x
  su dev -c "
    _doterra_state_pull_as_dev_user.sh \"$DECRYPTED_TFSTATE\""

  _dev_tty.sh "
    GPG_KEY_NAME=$GPG_KEY_NAME \
    _encrypt_file_as_dev_user.sh \"$ENCRYPTED_TFSTATE\" \"$DECRYPTED_TFSTATE\""
  set +x
}
trap sync_encrypted_tfstate EXIT

su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  _doterra_as_dev_user.sh \"$terraform_command\" \"/var/lib/terraform-020-chillbox/output.json\""

if [ "$terraform_command" = "apply" ]; then
  cat <<HERE
INFO $script_name: If initially deploying a new chillbox server.
  Log file for the user data script will be on the server at:
    /var/log/chillbox-init/*.log
  The output variables from terraform are in this json file and may contain sensitive values:
    /var/lib/terraform-020-chillbox/output.json
HERE
fi
