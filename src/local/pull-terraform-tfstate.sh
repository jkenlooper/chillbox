#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

export CHILLBOX_INSTANCE="${CHILLBOX_INSTANCE:-default}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (printf '\n%s\n' "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  printf '\n%s\n' "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

env_config="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE/env"
if [ -f "${env_config}" ]; then
  # shellcheck source=/dev/null
  . "${env_config}"
else
  echo "ERROR $0: No $env_config file found."
  exit 1
fi

chillbox_build_artifact_vars_file="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE/build-artifacts-vars"
test -e "$chillbox_build_artifact_vars_file" || (echo "ERROR $0: No $chillbox_build_artifact_vars_file file found. Should run the ./terra.sh script first to build artifacts." && exit 1)
# SITES_ARTIFACT=""
# SITES_MANIFEST=""
# shellcheck source=/dev/null
. "$chillbox_build_artifact_vars_file"

# The WORKSPACE is passed as a build-arg for the images, so make the image and
# container name also have that in their name.
export INFRA_IMAGE="chillbox-terraform-010-infra:latest"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox:latest"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$CHILLBOX_INSTANCE-$WORKSPACE"

chillbox_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

backup_terraform_state_dir="${BACKUP_TERRAFORM_STATE_DIR:-${chillbox_data_home}/terraform_state_backup}"
mkdir -p "$backup_terraform_state_dir"

state_infra_json="$backup_terraform_state_dir/${INFRA_CONTAINER}-terraform.tfstate.json"

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

"$project_dir/src/local/_docker_build_terraform-010-infra.sh"

docker run \
  -i --tty \
  --user root \
  --rm \
  --name "${INFRA_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=true" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=true" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
  --mount "type=bind,src=${state_infra_json},dst=/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json,readonly=false" \
  --entrypoint="" \
  "$INFRA_IMAGE" doterra-state-pull.sh "/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json"
printf '\n%s\n' "Created $state_infra_json"


state_chillbox_json="$backup_terraform_state_dir/${TERRAFORM_CHILLBOX_CONTAINER}-terraform.tfstate.json"
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

"$project_dir/src/local/_docker_build_terraform-020-chillbox.sh"

docker run \
  -i --tty \
  --user root \
  --rm \
  --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=true" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=true" \
  --mount "type=volume,src=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
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
