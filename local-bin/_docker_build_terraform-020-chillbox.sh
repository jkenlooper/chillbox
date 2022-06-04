#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

docker rm "${TERRAFORM_CHILLBOX_CONTAINER}" || printf ""
docker image rm "$TERRAFORM_CHILLBOX_IMAGE" || printf ""

export DOCKER_BUILDKIT=1
docker build \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "${TERRAFORM_CHILLBOX_IMAGE}" \
  -f "${project_dir}/terraform-020-chillbox.Dockerfile" \
  "${project_dir}"

