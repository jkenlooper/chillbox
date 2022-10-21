#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Wrapper around the ansible command. Use '--' to pass an option to the ansible command if no arg is used.

If an interactive session with an ansible command is needed then should just do
'su dev' command after decrypting the private ssh key for ansible.

Usage:
  $script_name -h
  $script_name -- --help
  $script_name
  $script_name -- <options> <pattern>
  $script_name <pattern>
  $script_name -s <sub-command> -- <options> <args>

Options:
  -h                  Show this help message.
  -s <sub-command>    Run ansible sub command like playbook, console, etc.

Examples:
  Just decrypt the private ssh key for ansible and switch to dev user. Use this
  command if running ansible commands interactively.
  $script_name && su dev

  Run the command "ansible -m command -a 'whoami' localhost".
  $script_name -- -m command -a 'whoami' localhost

  Run one or more playbooks.
  $script_name -s playbook -- playbook [playbook ...]
HERE
}

sub_command=""

while getopts "hs:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) sub_command=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

ciphertext_ansible_private_ssh_key_file=/var/lib/chillbox-gnupg/ansible.pem.asc

secure_tmp_ssh_dir=/run/tmp/ansible/ssh
mkdir -p "$secure_tmp_ssh_dir"
chown -R dev:dev "$(dirname "$secure_tmp_ssh_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_ssh_dir")"

plaintext_ansible_private_ssh_key_file="$secure_tmp_ssh_dir/ansible.pem"
if [ ! -f "$plaintext_ansible_private_ssh_key_file" ]; then
  echo "INFO $script_name: Decrypting file $ciphertext_ansible_private_ssh_key_file to $plaintext_ansible_private_ssh_key_file"
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"$ciphertext_ansible_private_ssh_key_file\" \"$plaintext_ansible_private_ssh_key_file\""
  set +x
fi

ciphertext_terraform_010_infra_output_file=/var/lib/terraform-010-infra/output.json.asc
if [ ! -f "$ciphertext_terraform_010_infra_output_file" ]; then
  echo "ERROR $script_name: Missing file: $ciphertext_terraform_010_infra_output_file"
  exit 1
fi
secure_tmp_terraform_dir=/run/tmp/ansible/terraform
mkdir -p "$secure_tmp_terraform_dir"
chown -R dev:dev "$(dirname "$secure_tmp_terraform_dir")"
chmod -R 0700 "$(dirname "$secure_tmp_terraform_dir")"
plaintext_terraform_010_infra_output_file="$secure_tmp_terraform_dir/terraform-010-infra-output.json"
if [ ! -f "$plaintext_terraform_010_infra_output_file" ]; then
  echo "INFO $0: Decrypting file $ciphertext_terraform_010_infra_output_file to $plaintext_terraform_010_infra_output_file"
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"$ciphertext_terraform_010_infra_output_file\" \"$plaintext_terraform_010_infra_output_file\""
  set +x
fi
# Convert the terraform output json file to a simple key:value for ansible vars to use.
jq -r '. | to_entries | map({(.key|tostring):.value.value}) | add' "$plaintext_terraform_010_infra_output_file"  > /run/tmp/ansible/terraform/vars.json

# Only need to run the ansible commands if an arg was passed.
if [ -n "$1" ]; then
  cmd="$(which ansible)"
  if [ -n "$sub_command" ]; then
    cmd="$(which "ansible-$sub_command")"
  fi
  su dev -s "$cmd" -- "$@"
fi
