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

mkdir -p "/home/dev/.aws"
chown -R dev:dev "$(dirname "/home/dev/.aws")"
chmod -R 0700 "$(dirname "/home/dev/.aws")"

chown dev "$(tty)"
su dev -c "secure_tmp_secrets_dir=$secure_tmp_secrets_dir \
  WORKSPACE=$WORKSPACE \
  _doterra_as_dev_user.sh '$terraform_command'"
chown root "$(tty)"
