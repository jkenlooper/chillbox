#!/usr/bin/env bash

# Helper script for isolating use of terraform in a container.

set -o errexit

WORKSPACE=development

project_dir="$(dirname $(realpath $0))"
terraform_infra_dir="$project_dir/terraform-010-infra"
terraform_chillbox_dir="$project_dir/terraform-020-chillbox"

# Allow setting defaults from an env file
ENV_CONFIG=${1:-"$project_dir/.env"}
test -f "${ENV_CONFIG}" && source "${ENV_CONFIG}"

# Create this file by following instructions at jkenlooper/alpine-droplet
ALPINE_CUSTOM_IMAGE=${ALPINE_CUSTOM_IMAGE:-"https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-01-27-1339/alpine-virt-image-2022-01-27-1339.qcow2.bz2"}
test -n "${ALPINE_CUSTOM_IMAGE}" || (echo "ERROR $0: ALPINE_CUSTOM_IMAGE variable is empty" && exit 1)
echo "INFO $0: Using ALPINE_CUSTOM_IMAGE '${ALPINE_CUSTOM_IMAGE}'"
ALPINE_CUSTOM_IMAGE_CHECKSUM=${ALPINE_CUSTOM_IMAGE_CHECKSUM:-"d68d789f9e8f957f41fc4b4cf26a31b5"}
test -n "${ALPINE_CUSTOM_IMAGE_CHECKSUM}" || (echo "ERROR $0: ALPINE_CUSTOM_IMAGE_CHECKSUM variable is empty" && exit 1)
echo "INFO $0: Using ALPINE_CUSTOM_IMAGE_CHECKSUM '${ALPINE_CUSTOM_IMAGE_CHECKSUM}'"


example_sites_git_repo="git@github.com:jkenlooper/chillbox-sites-example.git"
SITES_GIT_REPO=${SITES_GIT_REPO:-"$example_sites_git_repo"}
test -n "${SITES_GIT_REPO}" || (echo "ERROR $0: SITES_GIT_REPO variable is empty" && exit 1)
echo "INFO $0: Using SITES_GIT_REPO '${SITES_GIT_REPO}'"
if [ "${SITES_GIT_REPO}" = "${example_sites_git_repo}" ]; then
  echo "WARNING $0: Using the example sites repo."
  read -p "Deploy using the example sites repo? [y/n]
  " confirm_using_example_sites_repo
  test "${confirm_using_example_sites_repo}" = "y" || (echo "Exiting" && exit 2)
  echo "INFO $0: Continuing to use example sites git repository."
fi
SITES_GIT_BRANCH=${SITES_GIT_BRANCH:-"main"}
test -n "${SITES_GIT_BRANCH}" || (echo "ERROR $0: SITES_GIT_BRANCH variable is empty" && exit 1)
echo "INFO $0: Using SITES_GIT_BRANCH '${SITES_GIT_BRANCH}'"

# Should be console, plan, apply, or destroy
terraform_command=$1

# Build the artifacts
cd "${project_dir}"
eval "$(jq \
  --arg jq_sites_git_repo "$SITES_GIT_REPO" \
  --arg jq_sites_git_branch "$SITES_GIT_BRANCH" \
  --null-input '{
    sites_git_repo: $jq_sites_git_repo,
    sites_git_branch: $jq_sites_git_branch,
}' | ./build-artifacts.sh | jq -r '@sh "
    SITES_ARTIFACT=\(.sites_artifact)
    CHILLBOX_ARTIFACT=\(.chillbox_artifact)
    SITES_MANIFEST=\(.sites_manifest)
    "')"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $0: The SITES_ARTIFACT variable is empty." && exit 1)
test -n "${CHILLBOX_ARTIFACT}" || (echo "ERROR $0: The CHILLBOX_ARTIFACT variable is empty." && exit 1)
test -n "${SITES_MANIFEST}" || (echo "ERROR $0: The SITES_MANIFEST variable is empty." && exit 1)


cd "${terraform_infra_dir}"

infra_image="chillbox-$(basename $terraform_infra_dir)"
infra_container="chillbox-$(basename $terraform_infra_dir)"
docker rm "${infra_container}" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "$infra_image" \
  .

docker run \
  -i --tty \
  --name "${infra_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0777" \
  --mount 'type=volume,src=chillbox-terraform-dev-dotgnupg,dst=/home/dev/.gnupg,readonly=false' \
  --mount 'type=volume,src=chillbox-terraform-dev-terraformdotd,dst=/home/dev/.terraform.d,readonly=false' \
  --mount 'type=volume,src=chillbox-terraform-var-lib,dst=/var/lib/doterra,readonly=false' \
  --entrypoint="" \
  "$infra_image" doterra-init.sh
docker cp "${infra_container}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" ./
docker rm "${infra_container}"

docker run \
  -i --tty \
  --rm \
  --name "${infra_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0777" \
  --mount 'type=volume,src=chillbox-terraform-dev-dotgnupg,dst=/home/dev/.gnupg,readonly=false' \
  --mount 'type=volume,src=chillbox-terraform-dev-terraformdotd,dst=/home/dev/.terraform.d,readonly=false' \
  --mount 'type=volume,src=chillbox-terraform-var-lib,dst=/var/lib/doterra,readonly=false' \
  --mount "type=bind,src=${terraform_infra_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_infra_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --entrypoint="" \
  "$infra_image" sh

docker run \
  --rm \
  --name "${infra_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount 'type=volume,src=chillbox-terraform-dev-terraformdotd,dst=/home/dev/.terraform.d,readonly=false' \
  --mount "type=bind,src=${terraform_infra_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_infra_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  "$infra_image" output -json > "${terraform_chillbox_dir}/${infra_container}.output.json"

# Start the chillbox terraform
cd "${terraform_chillbox_dir}"

terraform_chillbox_image="chillbox-$(basename $terraform_chillbox_dir)"
terraform_chillbox_container="chillbox-$(basename $terraform_chillbox_dir)"
docker rm "${terraform_chillbox_container}" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg ALPINE_CUSTOM_IMAGE=$ALPINE_CUSTOM_IMAGE \
  --build-arg ALPINE_CUSTOM_IMAGE_CHECKSUM=$ALPINE_CUSTOM_IMAGE_CHECKSUM \
  --build-arg SITES_ARTIFACT=$SITES_ARTIFACT \
  --build-arg CHILLBOX_ARTIFACT=$CHILLBOX_ARTIFACT \
  --build-arg SITES_MANIFEST=$SITES_MANIFEST \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "$terraform_chillbox_image" \
  .

docker run \
  --name "${terraform_chillbox_container}" \
  "$terraform_chillbox_image" init
docker cp "${terraform_chillbox_container}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" ./
docker rm "${terraform_chillbox_container}"

docker run \
  -i --tty \
  --rm \
  --name "${terraform_chillbox_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0777" \
  --mount 'type=volume,src=chillbox-terraform-dev-dotgnupg,dst=/home/dev/.gnupg,readonly=false' \
  --mount 'type=volume,src=chillbox-terraform-dev-terraformdotd,dst=/home/dev/.terraform.d,readonly=false' \
  --mount 'type=volume,src=chillbox-terraform-var-lib,dst=/var/lib/doterra,readonly=false' \
  --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/alpine-box-init.sh.tftpl,dst=/usr/local/src/chillbox-terraform/alpine-box-init.sh.tftpl" \
  --mount "type=bind,src=${terraform_chillbox_dir}/private.auto.tfvars,dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --mount "type=bind,src=${project_dir}/dist,dst=/usr/local/src/chillbox-terraform/dist" \
  --entrypoint="" \
  "$terraform_chillbox_image" sh
