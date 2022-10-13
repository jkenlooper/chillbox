#!/usr/bin/env sh

# Helper script for isolating use of terraform in a container.

set -o errexit

script_name="$(basename "$0")"

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"


# This script shouldn't be run directly. Do a sanity check still.
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $script_name: CHILLBOX_INSTANCE variable is empty" && exit 1)
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)

chillbox_config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

export GNUPG_IMAGE="chillbox-gnupg:latest"
export GNUPG_CONTAINER="chillbox-gnupg-$CHILLBOX_INSTANCE-$WORKSPACE"

"$project_dir/src/local/gnupg/docker-build-gnupg.sh"

docker run \
  -i --tty \
  --name "$GNUPG_CONTAINER" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/doterra,readonly=false" \
  --mount "type=bind,src=$chillbox_build_artifact_vars_file,dst=/var/lib/chillbox-build-artifacts-vars,readonly=true" \
  --entrypoint="" \
  "$GNUPG_IMAGE" doterra-init.sh || (
    exitcode="$?"
    echo "docker exited with $exitcode exitcode. Continue? [y/n]"
    read -r docker_continue_confirm
    test "$docker_continue_confirm" = "y" || exit $exitcode
  )

