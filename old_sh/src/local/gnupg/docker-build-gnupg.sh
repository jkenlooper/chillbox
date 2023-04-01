#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")")"
script_name="$(basename "$0")"

docker rm "$GNUPG_CONTAINER" > /dev/null 2>&1 || printf ""
docker image rm "$GNUPG_IMAGE" > /dev/null 2>&1 || printf ""

echo "INFO $script_name: Building docker image: $GNUPG_IMAGE"
DOCKER_BUILDKIT=1 docker build \
  --quiet \
  -t "$GNUPG_IMAGE" \
  -f "$project_dir/src/local/gnupg/gnupg.Dockerfile" \
  "$project_dir/src/local/gnupg"
