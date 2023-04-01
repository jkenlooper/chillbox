#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

# This script shouldn't be run directly. Do a sanity check still.
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $script_name: CHILLBOX_INSTANCE variable is empty" && exit 1)
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)

public_key_for_ansible="$1"
test "${public_key_for_ansible%.pem.pub}" != "$public_key_for_ansible" || (echo "ERROR $script_name: Should have arg end with '.pem.pub'" && exit 1)

if [ -e "$public_key_for_ansible" ]; then
  echo "INFO $script_name: Public ssh key exists for ansible to use; skipping creation of new one."
  echo "INFO $script_name: $public_key_for_ansible"
  exit 0
fi

export GNUPG_IMAGE="chillbox-gnupg:latest"
export GNUPG_CONTAINER="chillbox-gnupg-$CHILLBOX_INSTANCE-$WORKSPACE"

"$project_dir/src/local/gnupg/docker-build-gnupg.sh"

docker run \
  -i --tty \
  --user root \
  --name "$GNUPG_CONTAINER" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-gnupg-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/chillbox-gnupg,readonly=false" \
  "$GNUPG_IMAGE" || (
    exitcode="$?"
    echo "docker exited with $exitcode exitcode. Continue? [y/n]"
    read -r docker_continue_confirm
    test "$docker_continue_confirm" = "y" || exit $exitcode
  )

docker cp "$GNUPG_CONTAINER:/var/lib/chillbox-gnupg/ansible.pem.pub" "$public_key_for_ansible"

docker rm "$GNUPG_CONTAINER"
