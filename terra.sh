#!/usr/bin/env bash

# Helper script for using terraform commands in a workspace.
# Don't use this script if doing anything other then mundane main commands like
# console, plan, apply, or destroy.

set -o errexit

# TODO Split up to have two terraform deployments: chillbox-infra, chillbox-server.
# 0. Run build-artifact.sh to create the artifact files
#      - move upload bits of build-artifacts.sh into upload-artifacts.sh
# 1. Run terraform command on chillbox-infrastructure first to create or update
#    the resources like s3 bucket and other supporting bits.
#      - Create separate terraform directory for chillbox-infra (s3 buckets)
#      - Create separate terraform directory for chillbox-server (droplets,
#        DNS records for domains)
# 2. Upload the built artifacts and extract and upload the immutable.
# 3. Run terraform command for chillbox-server to deploy chillbox droplet and
#    other resources needed.

# ---

#  program = ["../build-artifacts.sh"]
#  query = {
#    immutable_bucket_name = digitalocean_spaces_bucket.immutable.name
#    artifact_bucket_name  = digitalocean_spaces_bucket.artifact.name
#    endpoint_url          = "https://${digitalocean_spaces_bucket.artifact.region}.digitaloceanspaces.com/"
#    chillbox_url          = "https://${var.sub_domain}${var.domain}"
#  }

terraform_dir="$(dirname $(realpath $0))"
project_dir="$(dirname $terraform_dir)"

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


cd "${terraform_dir}"

export DOCKER_BUILDKIT=1
docker build \
  --build-arg ALPINE_CUSTOM_IMAGE=$ALPINE_CUSTOM_IMAGE \
  --build-arg ALPINE_CUSTOM_IMAGE_CHECKSUM=$ALPINE_CUSTOM_IMAGE_CHECKSUM \
  --build-arg WORKSPACE=development \
  -t chillbox-terraform \
  .


docker run \
  --name chillbox-terraform \
  chillbox-terraform init
docker cp chillbox-terraform:/usr/local/src/chillbox-terraform/.terraform.lock.hcl ./
docker rm chillbox-terraform

exit 0

docker run \
  --rm \
  -e WORKSPACE=development \
  --name chillbox-terraform \
  chillbox-terraform output

# TODO set the variables and then execute the build-artifacts.sh

exit 0

# TODO if init then drop the user in
docker run \
  -i --tty \
  --rm \
  --name chillbox-terraform \
  -e WORKSPACE=development \
  --mount "type=bind,src=${terraform_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_dir}/alpine-box-init.sh.tftpl,dst=/usr/local/src/chillbox-terraform/alpine-box-init.sh.tftpl" \
  --mount "type=bind,src=${terraform_dir}/private.auto.tfvars,dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --entrypoint="" \
  chillbox-terraform sh

exit 0

# run normal command
docker run \
  -i --tty \
  --rm \
  -e WORKSPACE=development \
  --mount "type=bind,src=${terraform_dir},dst=/usr/local/src/chillbox-terraform" \
  --entrypoint="" \
  chillbox-terraform doterra.sh plan

# can run other terraform commands
docker run \
  -i --tty \
  --rm \
  -e WORKSPACE=development \
  --mount "type=bind,src=${terraform_dir},dst=/usr/local/src/chillbox-terraform" \
  chillbox-terraform workspace show
