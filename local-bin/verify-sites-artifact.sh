#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"
verified_sites_artifact_file="$working_dir/dist/.verified_sites_artifact"
verify_sites_container="chillbox-verify-sites"
verify_sites_image="chillbox-verify-sites"

export CHILLBOX_INSTANCE="${CHILLBOX_INSTANCE:-default}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $script_name: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

chillbox_build_artifact_vars_file="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE/build-artifacts-vars"
if [ -f "${chillbox_build_artifact_vars_file}" ]; then
  # shellcheck source=/dev/null
  . "${chillbox_build_artifact_vars_file}"
else
  echo "ERROR $0: No $chillbox_build_artifact_vars_file file found."
  exit 1
fi


SITES_ARTIFACT="${SITES_ARTIFACT:-}"
sites_artifact_file="$working_dir/dist/$SITES_ARTIFACT"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -e "${sites_artifact_file}" || (echo "ERROR $script_name: No file found at '$sites_artifact_file'." && exit 1)

SITES_MANIFEST="${SITES_MANIFEST:-}"
sites_manifest_file="$working_dir/dist/$SITES_MANIFEST"
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)
test -e "${sites_manifest_file}" || (echo "ERROR $script_name: No sites manifest file found at '$sites_manifest_file'." && exit 1)

if [ -e "$verified_sites_artifact_file" ]; then
  echo "INFO $script_name: Site has already been verified; skipping."
  exit 0
fi

docker rm "$verify_sites_container" || printf ""
docker image rm "$verify_sites_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  -t "$verify_sites_image" \
  -f "${working_dir}/verify-sites.Dockerfile" \
  "${working_dir}"

docker run \
  -i --tty \
  --rm \
  --env SITES_ARTIFACT="${SITES_ARTIFACT}" \
  --env SITES_MANIFEST="${SITES_MANIFEST}" \
  --name "${verify_sites_container}" \
  --mount "type=bind,src=$working_dir/dist,dst=/var/lib/verify-sites/dist" \
  "$verify_sites_image"

echo "INFO $script_name: Sites artifact ($SITES_ARTIFACT) is valid."
echo "INFO $script_name: Sites manifest ($SITES_MANIFEST) is valid."
# Create this verified sites artifact file to show that it passed.
touch "$verified_sites_artifact_file"
