#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

docker rm "$TERRAFORM_CHILLBOX_CONTAINER" > /dev/null 2>&1 || printf ""
docker image rm "$TERRAFORM_CHILLBOX_IMAGE" > /dev/null 2>&1 || printf ""

echo "INFO $script_name: Building docker image: $TERRAFORM_CHILLBOX_IMAGE"
DOCKER_BUILDKIT=1 docker build \
  --quiet \
  --build-arg SITES_ARTIFACT="$SITES_ARTIFACT" \
  --build-arg CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT" \
  --build-arg SITES_MANIFEST="$SITES_MANIFEST" \
  -t "$TERRAFORM_CHILLBOX_IMAGE" \
  -f "$project_dir/src/terraform/020-chillbox/chillbox.Dockerfile" \
  "$project_dir/src/terraform"
