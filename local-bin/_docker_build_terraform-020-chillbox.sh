#!/usr/bin/env sh

set -o errexit
set -o nounset

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

build_tmp_log="$(mktemp)"
cleanup() {
  rm "$build_tmp_log"
}
trap cleanup EXIT

docker rm "${TERRAFORM_CHILLBOX_CONTAINER}" || printf ""
docker image rm "$TERRAFORM_CHILLBOX_IMAGE" || printf ""

set +o errexit
export DOCKER_BUILDKIT=1
set -x
docker build \
  --progress=plain \
  --build-arg SITES_ARTIFACT="$SITES_ARTIFACT" \
  --build-arg CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT" \
  --build-arg SITES_MANIFEST="$SITES_MANIFEST" \
  -t "${TERRAFORM_CHILLBOX_IMAGE}" \
  -f "${project_dir}/terraform-020-chillbox.Dockerfile" \
  "${project_dir}" > "$build_tmp_log" 2>&1
docker_build_exit="$?"
set +x
set -o errexit
if [ "$docker_build_exit" -ne 0 ]; then
  cat "$build_tmp_log"
fi

exit "$docker_build_exit"
