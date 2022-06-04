#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

# Allow setting defaults from an env file
ENV_CONFIG=${1:-"$project_dir/.env"}
# shellcheck source=/dev/null
test -f "${ENV_CONFIG}" && . "${ENV_CONFIG}"

WORKSPACE="${WORKSPACE:-development}"
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
printf '\n%s\n' "Executing 'terraform state push' on ${INFRA_CONTAINER}"

"$project_dir/local-bin/_docker_build_terraform-010-infra.sh"

if [ -s "$state_infra_json" ]; then
  docker run \
    -i --tty \
    --rm \
    --name "${INFRA_CONTAINER}" \
    -e WORKSPACE="${WORKSPACE}" \
    --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
    --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
    --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
    --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
    --mount "type=bind,src=${state_infra_json},dst=/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json" \
    --entrypoint="" \
    "$INFRA_IMAGE" doterra-state-push.sh "/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json"

  printf '\n%s\n' "Pushed $state_infra_json"
else
  printf '\n%s\n' "WARNING $0: No $state_infra_json file or it is empty."
fi


state_chillbox_json="$backup_terraform_state_dir/$WORKSPACE/${TERRAFORM_CHILLBOX_CONTAINER}-terraform.tfstate.json"
printf '\n%s\n' "Executing 'terraform state push' on ${TERRAFORM_CHILLBOX_CONTAINER}"

"$project_dir/local-bin/_docker_build_terraform-020-chillbox.sh"

if [ -s "$state_chillbox_json" ]; then
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
    "$TERRAFORM_CHILLBOX_IMAGE" doterra-state-push.sh "/usr/local/src/chillbox-terraform/${TERRAFORM_CHILLBOX_CONTAINER}.json"
  printf '\n%s\n' "Pushed $state_chillbox_json"
else
  printf '\n%s\n' "WARNING $0: No $state_chillbox_json file or it is empty."
fi
