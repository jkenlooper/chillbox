#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(realpath "$0")")"
ansible_dir="$project_dir/src/ansible"

export CHILLBOX_INSTANCE=ansibletest
export WORKSPACE=development

INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"
TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$CHILLBOX_INSTANCE-$WORKSPACE"

export ANSIBLE_IMAGE="chillbox-ansible:latest"
export ANSIBLE_CONTAINER="chillbox-ansible-$CHILLBOX_INSTANCE-$WORKSPACE"

"$project_dir/src/local/_docker_build_ansible.sh"

# The private key file is set in the ansible config so ssh-agent doesn't have to
# be used. The private ssh key should not be generated with a passphrase when
# doing it this way.
# private_key_file=/run/tmp/ansible/ssh/ansible.pem
#
# ssh key setup
# https://docs.ansible.com/ansible/latest/user_guide/connection_details.html

docker run \
  -i --tty \
  --rm \
  --name "$ANSIBLE_CONTAINER" \
  --env CHILLBOX_INSTANCE \
  --env WORKSPACE \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/run/tmp/ansible,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-gnupg-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/chillbox-gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-ansible-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/ansible,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/doterra,readonly=true" \
  --mount "type=volume,src=chillbox-$INFRA_CONTAINER-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=volume,src=chillbox-$TERRAFORM_CHILLBOX_CONTAINER-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/terraform-020-chillbox,readonly=true" \
  --mount "type=bind,src=$ansible_dir/bin,dst=/usr/local/src/chillbox-ansible/bin" \
  --mount "type=bind,src=$ansible_dir/playbooks,dst=/usr/local/src/chillbox-ansible/playbooks" \
  "$ANSIBLE_IMAGE"
