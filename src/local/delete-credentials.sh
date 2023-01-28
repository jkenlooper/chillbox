#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

# This script shouldn't be run directly. Do a sanity check still.
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $script_name: CHILLBOX_INSTANCE variable is empty" && exit 1)
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)

usage() {
  cat <<HERE
Prompts to delete the encrypted credential files used to authenticate with the
hosting provider (DigitalOcean). When these files don't exist; the deploy script
will prompt to recreate them as necessary.

Usage:
  $0

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

encrypted_do_token=/var/lib/doterra/secrets/do_token.tfvars.json.asc
encrypted_terraform_spaces=/var/lib/doterra/secrets/terraform_spaces.tfvars.json.asc
encrypted_chillbox_spaces=/var/lib/doterra/secrets/chillbox_spaces.tfvars.json.asc

# Sleeper image needs no context.
sleeper_image="chillbox-sleeper"
docker image rm "$sleeper_image" > /dev/null 2>&1 || printf ""
export DOCKER_BUILDKIT=1
echo "INFO $script_name: Building docker image: $sleeper_image"
< "$project_dir/src/local/secrets/sleeper.Dockerfile" \
  docker build \
    --quiet \
    -t "$sleeper_image" \
    -

for encrypted_file in \
  "$encrypted_do_token" \
  "$encrypted_terraform_spaces" \
  "$encrypted_chillbox_spaces"; do
  # TODO use the same dev user
  docker run \
    -it \
    --rm \
    -u root \
    --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
    "$sleeper_image" rm -v -i "$encrypted_file" \
    || (
      exitcode="$?"
      echo "docker exited with $exitcode exitcode. Ignoring"
    )
done

