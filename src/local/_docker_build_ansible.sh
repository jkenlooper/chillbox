#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

build_tmp_log="$(mktemp)"
cleanup() {
  rm "$build_tmp_log"
}
trap cleanup EXIT

docker rm "${ANSIBLE_CONTAINER}" || printf ""
docker image rm "$ANSIBLE_IMAGE" || printf ""

set +o errexit
export DOCKER_BUILDKIT=1
set -x
docker build \
  --progress=plain \
  -t "$ANSIBLE_IMAGE" \
  -f "${project_dir}/src/ansible/ansible.Dockerfile" \
  "${project_dir}/src/ansible" > "$build_tmp_log" 2>&1
docker_build_exit="$?"

set +x
set -o errexit
if [ "$docker_build_exit" -ne 0 ]; then
  cat "$build_tmp_log"
fi

exit "$docker_build_exit"
