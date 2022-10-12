#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(realpath "$0")")"

export CHILLBOX_INSTANCE=ansibletest
export WORKSPACE=development

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
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/run/tmp/ansible,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-ansible-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/ansible,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/doterra,readonly=true" \
  "$ANSIBLE_IMAGE"
