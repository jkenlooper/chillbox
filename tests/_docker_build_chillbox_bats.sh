#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

build_tmp_log="$(mktemp)"
cleanup() {
  rm "$build_tmp_log"
}
trap cleanup EXIT

docker image rm "$CHILLBOX_BATS_IMAGE" || printf ""

# No context for the docker build is needed.
set +o errexit
export DOCKER_BUILDKIT=1
set -x

docker build --progress=plain -t "$CHILLBOX_BATS_IMAGE" - < "${project_dir}/tests/Dockerfile" \
 > "$build_tmp_log" 2>&1

docker_build_exit="$?"
set +x
set -o errexit
if [ "$docker_build_exit" -ne 0 ]; then
  cat "$build_tmp_log"
fi

exit "$docker_build_exit"
