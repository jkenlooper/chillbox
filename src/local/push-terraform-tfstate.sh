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

export INFRA_IMAGE="chillbox-terraform-010-infra:latest"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox:latest"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$CHILLBOX_INSTANCE-$WORKSPACE"

chillbox_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
ssh_keys_file="$chillbox_state_home/developer-public-ssh-keys.auto.tfvars.json"
terraform_infra_dir="$project_dir/src/terraform/010-infra"

chillbox_instance_and_environment_file="$chillbox_state_home/chillbox-instance-and-environment.auto.tfvars.json"

backup_terraform_state_dir="${BACKUP_TERRAFORM_STATE_DIR:-${chillbox_data_home}/terraform_state_backup}"
mkdir -p "$backup_terraform_state_dir"

state_infra_json="$backup_terraform_state_dir/${INFRA_CONTAINER}-terraform.tfstate.json"

printf '\n%s\n' "Executing 'terraform state push' on ${INFRA_CONTAINER}"

"$project_dir/src/local/_docker_build_terraform-010-infra.sh"

if [ -s "$state_infra_json" ]; then
  docker run \
    -i --tty \
    --rm \
    --name "${INFRA_CONTAINER}" \
    --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
    --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
    --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
    --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
    --mount "type=bind,src=$ssh_keys_file,dst=/usr/local/src/chillbox-terraform/developer-public-ssh-keys.auto.tfvars.json,readonly=true" \
    --mount "type=bind,src=${terraform_infra_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
    --mount "type=bind,src=${terraform_infra_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
    --mount "type=bind,src=${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
    --mount "type=bind,src=${chillbox_instance_and_environment_file},dst=/usr/local/src/chillbox-terraform/chillbox-instance-and-environment.auto.tfvars.json,readonly=true" \
    --mount "type=bind,src=$chillbox_build_artifact_vars_file,dst=/var/lib/chillbox-build-artifacts-vars,readonly=true" \
    --mount "type=bind,src=${state_infra_json},dst=/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json" \
    --entrypoint="" \
    "$INFRA_IMAGE" doterra-state-push.sh "/usr/local/src/chillbox-terraform/${INFRA_CONTAINER}.json"
    # TODO Fix the push so it updates the tfstate file that is encrypted.
    # "$INFRA_IMAGE" sh

  printf '\n%s\n' "Pushed $state_infra_json"
else
  printf '\n%s\n' "WARNING $0: No $state_infra_json file or it is empty."
fi


state_chillbox_json="$backup_terraform_state_dir/${TERRAFORM_CHILLBOX_CONTAINER}-terraform.tfstate.json"
printf '\n%s\n' "Executing 'terraform state push' on ${TERRAFORM_CHILLBOX_CONTAINER}"

"$project_dir/src/local/_docker_build_terraform-020-chillbox.sh"

if [ -s "$state_chillbox_json" ]; then
  docker run \
    -i --tty \
    --rm \
    --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
    --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
    --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
    --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
    --mount "type=volume,src=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
    --mount "type=bind,src=${state_chillbox_json},dst=/usr/local/src/chillbox-terraform/${TERRAFORM_CHILLBOX_CONTAINER}.json" \
    --entrypoint="" \
    "$TERRAFORM_CHILLBOX_IMAGE" doterra-state-push.sh "/usr/local/src/chillbox-terraform/${TERRAFORM_CHILLBOX_CONTAINER}.json"
  printf '\n%s\n' "Pushed $state_chillbox_json"
else
  printf '\n%s\n' "WARNING $0: No $state_chillbox_json file or it is empty."
fi
