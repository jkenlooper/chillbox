#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

docker rm "$INFRA_CONTAINER" > /dev/null 2>&1 || printf ""
docker image rm "$INFRA_IMAGE" > /dev/null 2>&1 || printf ""

echo "INFO $script_name: Building docker image: $INFRA_IMAGE"
DOCKER_BUILDKIT=1 docker build \
  --quiet \
  --build-arg SITES_ARTIFACT="$SITES_ARTIFACT" \
  --build-arg CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT" \
  --build-arg SITES_MANIFEST="$SITES_MANIFEST" \
  -t "$INFRA_IMAGE" \
  -f "$project_dir/src/terraform/010-infra/infra.Dockerfile" \
  "$project_dir/src/terraform"
