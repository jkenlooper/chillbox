#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

# Allow setting defaults from an env file
ENV_CONFIG=${1:-"$project_dir/.env"}
# shellcheck source=/dev/null
test -f "${ENV_CONFIG}" && . "${ENV_CONFIG}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (printf '\n%s\n' "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  printf '\n%s\n' "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

# The WORKSPACE is passed as a build-arg for the images, so make the image and
# container name also have that in their name.
export INFRA_IMAGE="chillbox-terraform-010-infra-$WORKSPACE"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox-$WORKSPACE"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$WORKSPACE"

backup_terraform_state_dir="${BACKUP_TERRAFORM_STATE_DIR:-${project_dir}/terraform_state_backup}"
mkdir -p "$backup_terraform_state_dir/$WORKSPACE"

state_infra_json="$backup_terraform_state_dir/$WORKSPACE/${INFRA_CONTAINER}-terraform.tfstate.json"

if [ -e "$state_infra_json.bak" ]; then
  printf '\n%s\n' "Remove old $state_infra_json.bak file first? [y/n]"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    shred -fu "$state_infra_json.bak"
  fi
fi
printf '\n%s\n' "Executing 'terraform state pull' on ${INFRA_CONTAINER}"
test ! -e "$state_infra_json" || mv --backup=numbered "$state_infra_json" "$state_infra_json.bak"
touch "$state_infra_json"

$project_dir/local-bin/_docker_build_terraform-010-infra.sh

docker run \
  -i --tty \
  --rm \
  --name "${INFRA_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
  --mount "type=bind,src=${state_infra_json},dst=/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json" \
  --entrypoint="" \
  "$INFRA_IMAGE" doterra-state-pull.sh "/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json"
printf '\n%s\n' "Created $state_infra_json"


state_chillbox_json="$backup_terraform_state_dir/$WORKSPACE/${TERRAFORM_CHILLBOX_CONTAINER}-terraform.tfstate.json"
if [ -e "$state_chillbox_json.bak" ]; then
  printf '\n%s\n' "Remove old $state_chillbox_json.bak file first? [y/n]"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    shred -fu "$state_chillbox_json.bak"
  fi
fi
printf '\n%s\n' "Executing 'terraform state pull' on ${TERRAFORM_CHILLBOX_CONTAINER}"
test ! -e "$state_chillbox_json" || mv --backup=numbered "$state_chillbox_json" "$state_chillbox_json.bak"
touch "$state_chillbox_json"

$project_dir/local-bin/_docker_build_terraform-020-chillbox.sh

docker run \
  -i --tty \
  --rm \
  --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
  --mount "type=bind,src=${state_chillbox_json},dst=/usr/local/src/chillbox-terraform/${TERRAFORM_CHILLBOX_CONTAINER}.json" \
  --entrypoint="" \
  "$TERRAFORM_CHILLBOX_IMAGE" doterra-state-pull.sh "/usr/local/src/chillbox-terraform/${TERRAFORM_CHILLBOX_CONTAINER}.json"
printf '\n%s\n' "Created $state_chillbox_json"

# It is up the user to encrypt these sensitive files once they have been
# decrypted and extracted out of the containers.
# TODO Could prompt for a public gpg key to use to encrypt these instead of
# bind mounting them in their non encrypted state.
printf '\n*********\n%s\n*********\n' "
WARNING:
The pulled json files contain sensitive data like the access secret key!
It is recommended to encrypt these files and/or store them somewhere secure.
"
