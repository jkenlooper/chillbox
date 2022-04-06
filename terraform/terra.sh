#!/usr/bin/env sh

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
#    sites_git_repo        = var.sites_git_repo
#    sites_git_branch      = var.sites_git_branch
#    immutable_bucket_name = digitalocean_spaces_bucket.immutable.name
#    artifact_bucket_name  = digitalocean_spaces_bucket.artifact.name
#    endpoint_url          = "https://${digitalocean_spaces_bucket.artifact.region}.digitaloceanspaces.com/"
#    chillbox_url          = "https://${var.sub_domain}${var.domain}"
#  }


# Create this file by following instructions at jkenlooper/alpine-droplet
#"https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-01-27-1339/alpine-virt-image-2022-01-27-1339.qcow2.bz2"
ALPINE_CUSTOM_IMAGE="https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-01-27-1339/alpine-virt-image-2022-01-27-1339.qcow2.bz2"
ALPINE_CUSTOM_IMAGE_CHECKSUM="d68d789f9e8f957f41fc4b4cf26a31b5"

# Should be console, plan, apply, or destroy
terraform_command=$1

# The terra.sh script needs to be executed from the top level of the project.
terraform_dir="$(dirname $(realpath $0))"
project_dir="$(dirname $terraform_dir)"
cd "${terraform_dir}"

export DOCKER_BUILDKIT=1
#cat "${terraform_dir}/Dockerfile" | docker build -t chillbox-terraform -
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
