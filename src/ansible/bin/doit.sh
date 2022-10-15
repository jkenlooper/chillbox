#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Wrapper around the ansible command.

Usage:
  $script_name -h
  $script_name <ansible args>

Options:
  -h                  Show this help message.

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

ansible_command=$*
if [ -z "$ansible_command" ]; then
  usage
  echo "ERROR $script_name: Must supply args for the ansible command."
  exit 1
fi

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

set -x
su dev -c "plaintext_ansible_private_ssh_key_file=$plaintext_ansible_private_ssh_key_file _ansible_as_dev_user.sh $ansible_command"
set +x
