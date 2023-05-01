#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"
script_name="$(basename "$0")"

docker image rm "$CHILLBOX_BATS_IMAGE" > /dev/null 2>&1 || printf ""

# No context for the docker build is needed.
echo "INFO $script_name: Building docker image: $CHILLBOX_BATS_IMAGE"
export DOCKER_BUILDKIT=1
docker build \
  --quiet \
  -t "$CHILLBOX_BATS_IMAGE" \
  - < "${project_dir}/tests/Dockerfile"
