#!/usr/bin/env sh

set -o errexit

echo "WARNING: The initial dev user password that was generated will be displayed to the screen."
echo "Continue? [y/n]"
read -r confirm
test "$confirm" = "y" || exit 1

# Need to decrypt the /run/tmp/ansible/terraform/terraform-010-infra-output.json
# file.
doit.sh

initial_dev_user_password="$(jq -r '.initial_dev_user_password.value' /run/tmp/ansible/terraform/terraform-010-infra-output.json)"
echo ""
echo "The initial dev user password is:"
echo "$initial_dev_user_password"
echo ""

echo "Use these commands to connect to the chillbox-0 server."
echo "doit.sh"
echo "ssh chillbox-0"
