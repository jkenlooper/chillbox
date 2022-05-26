#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"
terraform_infra_dir="$project_dir/terraform-010-infra"
terraform_chillbox_dir="$project_dir/terraform-020-chillbox"

infra_container="chillbox-$(basename "${terraform_infra_dir}")"
infra_image="chillbox-$(basename "${terraform_infra_dir}")"
terraform_chillbox_container="chillbox-$(basename "${terraform_chillbox_dir}")"
terraform_chillbox_image="chillbox-$(basename "${terraform_chillbox_dir}")"

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

backup_terraform_state_dir="${BACKUP_TERRAFORM_STATE_DIR:-${project_dir}/terraform_state_backup}"
mkdir -p "$backup_terraform_state_dir/$WORKSPACE"

state_infra_json="$backup_terraform_state_dir/$WORKSPACE/${infra_container}-terraform.tfstate.json"

if [ -e "$state_infra_json.bak" ]; then
  printf '\n%s\n' "Remove old $state_infra_json.bak file first? [y/n]"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    shred -fu "$state_infra_json.bak"
  fi
fi
printf '\n%s\n' "Executing 'terraform state pull' on ${infra_container}"
test ! -e "$state_infra_json" || mv --backup=numbered "$state_infra_json" "$state_infra_json.bak"
touch "$state_infra_json"
docker run \
  -i --tty \
  --rm \
  --name "${infra_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
  --mount "type=bind,src=${state_infra_json},dst=/usr/local/src/chillbox-terraform/${infra_container}.json" \
  --entrypoint="" \
  "$infra_image" doterra-state-pull.sh "/usr/local/src/chillbox-terraform/${infra_container}.json"
printf '\n%s\n' "Created $state_infra_json"


state_chillbox_json="$backup_terraform_state_dir/$WORKSPACE/${terraform_chillbox_container}-terraform.tfstate.json"
if [ -e "$state_chillbox_json.bak" ]; then
  printf '\n%s\n' "Remove old $state_chillbox_json.bak file first? [y/n]"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    shred -fu "$state_chillbox_json.bak"
  fi
fi
printf '\n%s\n' "Executing 'terraform state pull' on ${terraform_chillbox_container}"
test ! -e "$state_chillbox_json" || mv --backup=numbered "$state_chillbox_json" "$state_chillbox_json.bak"
touch "$state_chillbox_json"
docker run \
  -i --tty \
  --rm \
  --name "${terraform_chillbox_container}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${terraform_chillbox_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
  --mount "type=bind,src=${state_chillbox_json},dst=/usr/local/src/chillbox-terraform/${terraform_chillbox_container}.json" \
  --entrypoint="" \
  "$terraform_chillbox_image" doterra-state-pull.sh "/usr/local/src/chillbox-terraform/${terraform_chillbox_container}.json"
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
