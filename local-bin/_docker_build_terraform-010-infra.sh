#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

docker rm "${INFRA_CONTAINER}" || printf ""
docker image rm "$INFRA_IMAGE" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "$INFRA_IMAGE" \
  -f "${project_dir}/terraform-010-infra.Dockerfile" \
  "${project_dir}"
