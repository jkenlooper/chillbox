#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

docker rm "$ANSIBLE_CONTAINER" > /dev/null 2>&1 || printf ""
docker image rm "$ANSIBLE_IMAGE" > /dev/null 2>&1 || printf ""

echo "INFO $script_name: Building docker image: $ANSIBLE_IMAGE"
DOCKER_BUILDKIT=1 docker build \
  --quiet \
  -t "$ANSIBLE_IMAGE" \
  -f "$project_dir/src/ansible/ansible.Dockerfile" \
  "$project_dir/src/ansible"
