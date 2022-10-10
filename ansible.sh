#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(realpath "$0")")"

export CHILLBOX_INSTANCE=ansibletest
export WORKSPACE=development

export ANSIBLE_IMAGE="chillbox-ansible:latest"
export ANSIBLE_CONTAINER="chillbox-ansible-$CHILLBOX_INSTANCE-$WORKSPACE"

"$project_dir/src/local/_docker_build_ansible.sh"

docker run \
  -i --tty \
  --rm \
  --name "$ANSIBLE_CONTAINER" \
  "$ANSIBLE_IMAGE"
