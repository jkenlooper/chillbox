#!/usr/bin/env sh

# Helper script for using terraform commands in a workspace.
# Don't use this script if doing anything other then mundane main commands like
# console, plan, apply, or destroy.

set -o errexit

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
