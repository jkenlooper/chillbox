#!/usr/bin/env sh

# Helper script for isolating use of terraform in a container.

set -o errexit

terraform_command=${1:-interactive}
if [ "$terraform_command" != "interactive" ] && [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "ERROR $0: This command ($terraform_command) is not supported in this script."
  exit 1
fi

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
terraform_infra_dir="$project_dir/src/terraform/010-infra"
terraform_chillbox_dir="$project_dir/src/terraform/020-chillbox"

SKIP_UPLOAD="${SKIP_UPLOAD:-n}"

export CHILLBOX_INSTANCE="${CHILLBOX_INSTANCE:-default}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

chillbox_dist_file="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_ARTIFACT"
chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
chillbox_build_artifact_vars_file="$chillbox_state_home/build-artifacts-vars"
dist_sites_dir="$chillbox_state_home/sites"
site_domains_file="$chillbox_state_home/site_domains.auto.tfvars.json"

export INFRA_IMAGE="chillbox-terraform-010-infra:latest"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox:latest"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$CHILLBOX_INSTANCE-$WORKSPACE"

# start actual terraform stuff

"$project_dir/src/local/_docker_build_terraform-010-infra.sh"

cleanup_run_tmp_secrets() {
  docker stop "${INFRA_CONTAINER}" 2> /dev/null || printf ""
  docker rm "${INFRA_CONTAINER}" 2> /dev/null || printf ""
  docker stop "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""
  docker rm "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""

  # TODO support systems other then Linux that can't use a tmpfs mount. Will
  # need to always run a volume rm command each time the container stops to
  # simulate how tmpfs works on Linux.
  #docker volume rm "chillbox-terraform-run-tmp-secrets--$CHILLBOX_INSTANCE-${WORKSPACE}" || echo "ERROR $0: Failed to remove docker volume 'chillbox-terraform-run-tmp-secrets--$CHILLBOX_INSTANCE-${WORKSPACE}'. Does it exist?"
}
trap cleanup_run_tmp_secrets EXIT

echo "infra container $INFRA_CONTAINER"
docker run \
  -i --tty \
  --name "${INFRA_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --entrypoint="" \
  "$INFRA_IMAGE" doterra-init.sh

# TODO How to prevent updating the .terraform.lock.hcl file?
#      Move this action to 'make'?
docker cp "${INFRA_CONTAINER}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" "${terraform_infra_dir}/"

docker rm "${INFRA_CONTAINER}"

docker_run_infra_container() {
  # Change the command passed to the container to be 'doterra.sh $terraform_command'
  # instead of 'sh' if it is not set to be interactive.
  if [ "$terraform_command" != "interactive" ]; then
    set -- doterra.sh "$terraform_command"
  else
    set -- sh
  fi
  docker run \
    -i --tty \
    --rm \
    --name "${INFRA_CONTAINER}" \
    --hostname "${INFRA_CONTAINER}" \
    --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
    --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
    --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
    --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
    --mount "type=bind,src=${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
    --entrypoint="" \
    "$INFRA_IMAGE" "$@"
}
docker_run_infra_container

# Start the chillbox terraform

"$project_dir/src/local/_docker_build_terraform-020-chillbox.sh"

docker run \
  --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
  --user dev \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/user_data_chillbox.sh.tftpl,dst=/usr/local/src/chillbox-terraform/user_data_chillbox.sh.tftpl" \
  --mount "type=bind,src=${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --mount "type=bind,src=$chillbox_build_artifact_vars_file,dst=/var/lib/chillbox-build-artifacts-vars,readonly=true" \
  "$TERRAFORM_CHILLBOX_IMAGE" init
docker cp "${TERRAFORM_CHILLBOX_CONTAINER}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" "${terraform_chillbox_dir}/"
docker rm "${TERRAFORM_CHILLBOX_CONTAINER}"

docker_run_chillbox_container() {
  # Change the command passed to the container to be 'doterra.sh $terraform_command'
  # instead of 'sh' if it is not set to be interactive.
  if [ "$terraform_command" != "interactive" ]; then
    set -- doterra.sh "$terraform_command"
  else
    set -- sh
  fi
  docker run \
    -i --tty \
    --rm \
    --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
    --hostname "${TERRAFORM_CHILLBOX_CONTAINER}" \
    -e SKIP_UPLOAD="${SKIP_UPLOAD}" \
    --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
    --mount "type=tmpfs,dst=/home/dev/.aws,tmpfs-mode=0700" \
    --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
    --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
    --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
    --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
    --mount "type=volume,src=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
    --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
    --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
    --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
    --mount "type=bind,src=${terraform_chillbox_dir}/user_data_chillbox.sh.tftpl,dst=/usr/local/src/chillbox-terraform/user_data_chillbox.sh.tftpl" \
    --mount "type=bind,src=${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
    --mount "type=bind,src=$site_domains_file,dst=/usr/local/src/chillbox-terraform/site_domains.auto.tfvars.json,readonly=true" \
    --mount "type=bind,src=$chillbox_build_artifact_vars_file,dst=/var/lib/chillbox-build-artifacts-vars,readonly=true" \
    --mount "type=bind,src=$chillbox_dist_file,dst=/usr/local/src/chillbox-terraform/dist/$CHILLBOX_ARTIFACT,readonly=true" \
    --mount "type=bind,src=$chillbox_state_home/$SITES_MANIFEST,dst=/usr/local/src/chillbox-terraform/dist/$SITES_MANIFEST,readonly=true" \
    --mount "type=bind,src=$chillbox_state_home/$SITES_ARTIFACT,dst=/usr/local/src/chillbox-terraform/dist/$SITES_ARTIFACT,readonly=true" \
    --mount "type=bind,src=$dist_sites_dir,dst=/usr/local/src/chillbox-terraform/dist/sites,readonly=true" \
    --entrypoint="" \
    "$TERRAFORM_CHILLBOX_IMAGE" "$@"
}
docker_run_chillbox_container
