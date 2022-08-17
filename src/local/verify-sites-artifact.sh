#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

export CHILLBOX_INSTANCE="${CHILLBOX_INSTANCE:-default}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $script_name: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

verify_sites_image="chillbox-verify-sites:latest"
verify_sites_container="chillbox-verify-sites-$CHILLBOX_INSTANCE-$WORKSPACE"

chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

chillbox_build_artifact_vars_file="$chillbox_state_home/build-artifacts-vars"
if [ -f "${chillbox_build_artifact_vars_file}" ]; then
  # shellcheck source=/dev/null
  . "${chillbox_build_artifact_vars_file}"
else
  echo "ERROR $0: No $chillbox_build_artifact_vars_file file found."
  exit 1
fi


SITES_ARTIFACT="${SITES_ARTIFACT:-}"
sites_artifact_file="$chillbox_state_home/$SITES_ARTIFACT"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -e "${sites_artifact_file}" || (echo "ERROR $script_name: No file found at '$sites_artifact_file'." && exit 1)

SITES_MANIFEST="${SITES_MANIFEST:-}"
sites_manifest_file="$chillbox_state_home/$SITES_MANIFEST"
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)
test -e "${sites_manifest_file}" || (echo "ERROR $script_name: No sites manifest file found at '$sites_manifest_file'." && exit 1)

verified_sites_artifact_file="$chillbox_state_home/verified_sites_artifact/$SITES_ARTIFACT"
mkdir -p "$(dirname "$verified_sites_artifact_file")"

if [ -e "$verified_sites_artifact_file" ]; then
  echo "INFO $script_name: Site artifact $SITES_ARTIFACT has already been verified; skipping."
  exit 0
fi

docker rm "$verify_sites_container" || printf ""
docker image rm "$verify_sites_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  -t "$verify_sites_image" \
  -f "${project_dir}/src/local/verify-sites/verify-sites.Dockerfile" \
  "${project_dir}/src/local/verify-sites"

docker run \
  -i --tty \
  --rm \
  --env SITES_ARTIFACT="${SITES_ARTIFACT}" \
  --env SITES_MANIFEST="${SITES_MANIFEST}" \
  --name "${verify_sites_container}" \
  --mount "type=bind,src=$chillbox_state_home/$SITES_MANIFEST,dst=/var/lib/verify-sites/dist/$SITES_MANIFEST,readonly=true" \
  --mount "type=bind,src=$chillbox_state_home/$SITES_ARTIFACT,dst=/var/lib/verify-sites/dist/$SITES_ARTIFACT,readonly=true" \
  "$verify_sites_image"

echo "INFO $script_name: Sites artifact ($SITES_ARTIFACT) is valid."
echo "INFO $script_name: Sites manifest ($SITES_MANIFEST) is valid."
# Create this verified sites artifact file to show that it passed.
touch "$verified_sites_artifact_file"
