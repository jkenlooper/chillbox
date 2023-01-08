#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

usage() {
  cat <<HERE
For each site listed in the site manifest; build and run the secrets Dockerfile.
Copy the encrypted secrets from the container and upload to s3 artifacts bucket.
Usage:
  $0

HERE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done

export CHILLBOX_INSTANCE="${CHILLBOX_INSTANCE:-default}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $script_name: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

chillbox_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

encrypted_secrets_dir="${ENCRYPTED_SECRETS_DIR:-${chillbox_data_home}/encrypted-secrets}"

# TODO what variables does this script need?
# Allow setting defaults from an env file
env_config="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE/env"
if [ -f "${env_config}" ]; then
  # shellcheck source=/dev/null
  . "${env_config}"
else
  echo "ERROR $script_name: No $env_config file found."
  exit 1
fi

chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

# Lowercase the INFRA_CONTAINER var since it isn't exported.
infra_container="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"

chillbox_build_artifact_vars_file="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE/build-artifacts-vars"
test -e "$chillbox_build_artifact_vars_file" || (echo "ERROR $script_name: No $chillbox_build_artifact_vars_file file found. Should run the ./chillbox.sh script first to build artifacts." && exit 1)

SITES_ARTIFACT=""
SITES_MANIFEST=""
# shellcheck source=/dev/null
. "$chillbox_build_artifact_vars_file"

sites_artifact_file="$chillbox_state_home/$SITES_ARTIFACT"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -f "${sites_artifact_file}" || (echo "ERROR $script_name: No file found at '$sites_artifact_file'." && exit 1)

sites_manifest_file="$chillbox_state_home/$SITES_MANIFEST"
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)
test -f "${sites_manifest_file}" || (echo "ERROR $script_name: No sites manifest file found at '$sites_manifest_file'." && exit 1)

# Sleeper image needs no context.
sleeper_image="chillbox-sleeper"
docker image rm "$sleeper_image" || printf ""
export DOCKER_BUILDKIT=1
< "$project_dir/src/local/secrets/sleeper.Dockerfile" \
  docker build \
    -t "$sleeper_image" \
    -

s3_wrapper_image="chillbox-s3-wrapper:latest"
docker image rm "$s3_wrapper_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  -t "$s3_wrapper_image" \
  -f "${project_dir}/src/local/secrets/s3-wrapper.Dockerfile" \
  "${project_dir}/src/local/secrets"

s3_download_pubkeys_image="chillbox-s3-download-pubkeys:latest"
s3_download_pubkeys_container="chillbox-s3-download-pubkeys"
docker rm "${s3_download_pubkeys_container}" || printf ""
docker image rm "$s3_download_pubkeys_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  -t "$s3_download_pubkeys_image" \
  -f "${project_dir}/src/local/secrets/s3-download-pubkeys.Dockerfile" \
  "${project_dir}/src/local/secrets"
# Echo out something after a docker build to clear/reset the stdout.
clear && echo "INFO $script_name: finished docker build of $s3_download_pubkeys_image"

pubkey_dir="$(mktemp -d)"
tmp_sites_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_sites_dir"
  rm -rf "$pubkey_dir"
}
trap cleanup EXIT

docker run \
  -i --tty \
  --rm \
  --name "$s3_download_pubkeys_container" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/home/dev/.aws,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=true" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=bind,src=$pubkey_dir,dst=/var/lib/chillbox/public-keys" \
  --mount "type=bind,src=$chillbox_build_artifact_vars_file,dst=/var/lib/chillbox-build-artifacts-vars,readonly=true" \
  "$s3_download_pubkeys_image" || echo "TODO $0: Ignored error on s3 download of chillbox public keys."
# Echo out something after a docker run to clear/reset the stdout.
clear && echo "INFO $script_name: finished docker run of $s3_download_pubkeys_image"

# Provide encrypt-file script for the service handler container to use.
cp "$project_dir/src/local/secrets/encrypt-file" "$pubkey_dir"

tar x -f "$sites_artifact_file" -C "$tmp_sites_dir" sites
chmod --recursive u+rw "$tmp_sites_dir"

site_json_files="$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')"
for site_json in $site_json_files; do
  slugname="$(basename "$site_json" .site.json)"
  version="$(jq -r '.version' "$site_json")"
  no_metadata_version="$(printf "%s" "$version" | sed 's/+.*$//')"

  services="$(jq -c '.services // [] | .[]' "$site_json")"
  test -n "${services}" || continue
  for service_obj in $services; do
    test -n "${service_obj}" || continue
    secrets_config="$(echo "$service_obj" | jq -r '.secrets_config // ""')"
    test -n "$secrets_config" || continue
    service_handler="$(echo "$service_obj" | jq -r '.handler')"
    secrets_export_dockerfile="$(echo "$service_obj" | jq -r '.secrets_export_dockerfile // ""')"
    test -n "$secrets_export_dockerfile" || (echo "ERROR: No secrets_export_dockerfile value set in services, yet secrets_config is defined. $slugname - $service_obj" && exit 1)

    encrypted_secret_service_dir="$encrypted_secrets_dir/$slugname/$service_handler"
    mkdir -p "$encrypted_secret_service_dir"

    chillbox_hostnames="$(find "$pubkey_dir" -depth -maxdepth 1 -type f -name '*.public.pem' -exec basename {} .public.pem \;)"
    replace_secret_files=""
    for chillbox_hostname in $chillbox_hostnames; do
      encrypted_secret_file="$encrypted_secrets_dir/$slugname/$service_handler/$chillbox_hostname/$secrets_config"

      if [ -e "$encrypted_secret_file" ]; then
        echo "The encrypted file $slugname/$service_handler/$chillbox_hostname/$secrets_config already exists in $encrypted_secrets_dir"
        echo "Replace this file? y/n"
        read -r replace_secret_file
        test "$replace_secret_file" = "y" || continue
      fi
      replace_secret_files="y"
    done
    test "$replace_secret_files" = "y" || continue
    find "$encrypted_secrets_dir/$slugname/$service_handler" -depth -mindepth 2 -maxdepth 2 -type f -delete

    tmp_service_dir="$(mktemp -d)"
    tar x -z -f "$chillbox_state_home/sites/$slugname/$slugname-$version.artifact.tar.gz" -C "$tmp_service_dir" "$slugname/${service_handler}"

    test -f "$tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile" || (echo "ERROR: No secrets export dockerfile extracted at path: $tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile" && exit 1)

    service_image_name="$slugname-$no_metadata_version-$service_handler-$CHILLBOX_INSTANCE-$WORKSPACE"
    tmp_container_name="$(basename "$tmp_service_dir")-$slugname-$no_metadata_version-$service_handler"
    tmpfs_dir="/run/tmp/$service_image_name"
    service_persistent_dir="/var/lib/$slugname-$service_handler"
    chillbox_pubkey_dir="/var/lib/chillbox/public-keys"

    docker image rm "$service_image_name" || printf ""
    export DOCKER_BUILDKIT=1
    docker build \
      --build-arg SECRETS_CONFIG="$secrets_config" \
      --build-arg CHILLBOX_PUBKEY_DIR="$chillbox_pubkey_dir" \
      --build-arg TMPFS_DIR="$tmpfs_dir" \
      --build-arg SERVICE_PERSISTENT_DIR="$service_persistent_dir" \
      --build-arg SLUGNAME="$slugname" \
      --build-arg VERSION="$version" \
      --build-arg SERVICE_HANDLER="$service_handler" \
      -t "$service_image_name" \
      -f "$tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile" \
      "$tmp_service_dir/$slugname/$service_handler/"
    # Echo out something after a docker build to clear/reset the stdout.
    clear && echo "INFO $script_name: finished docker build of $service_image_name"

    clear && echo "INFO $script_name: Running the container $tmp_container_name in interactive mode to encrypt and upload secrets. This container is using docker image $service_image_name and the Dockerfile $tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile"
    docker run \
      -i --tty \
      --rm \
      --name "$tmp_container_name" \
      --mount "type=tmpfs,dst=$tmpfs_dir" \
      --mount "type=volume,src=chillbox-service-persistent-dir-var-lib-$CHILLBOX_INSTANCE-$WORKSPACE-$slugname-$service_handler,dst=$service_persistent_dir" \
      --mount "type=bind,src=$pubkey_dir,dst=$chillbox_pubkey_dir,readonly=true" \
      "$service_image_name" || (
        exitcode="$?"
        echo "docker exited with $exitcode exitcode. Continue? [y/n]"
        read -r docker_continue_confirm
        test "$docker_continue_confirm" = "y" || exit $exitcode
      )

    docker run \
      -d \
      --name "$tmp_container_name-sleeper" \
      --mount "type=volume,src=chillbox-service-persistent-dir-var-lib-$CHILLBOX_INSTANCE-$WORKSPACE-$slugname-$service_handler,dst=$service_persistent_dir" \
      "$sleeper_image" || (
        exitcode="$?"
        echo "docker exited with $exitcode exitcode. Ignoring"
      )
    docker cp "$tmp_container_name-sleeper:$service_persistent_dir/encrypted-secrets/." "$encrypted_secret_service_dir/" || echo "Ignore docker cp error."
    docker stop --time 0 "$tmp_container_name-sleeper" || printf ""
    docker rm "$tmp_container_name-sleeper" || printf ""

  done

done


s3_upload_encrypted_secrets_image="chillbox-s3-upload-encrypted-secrets:latest"
s3_upload_encrypted_secrets_container="chillbox-s3-upload-encrypted-secrets-$CHILLBOX_INSTANCE-$WORKSPACE"
docker rm "${s3_upload_encrypted_secrets_container}" || printf ""
docker image rm "$s3_upload_encrypted_secrets_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  -t "$s3_upload_encrypted_secrets_image" \
  -f "${project_dir}/src/local/secrets/s3-upload-encrypted-secrets.Dockerfile" \
  "${project_dir}/src/local/secrets"

docker run \
  -i --tty \
  --rm \
  --name "$s3_upload_encrypted_secrets_container" \
  --mount "type=tmpfs,dst=/home/dev/.aws,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=bind,src=$encrypted_secrets_dir,dst=/var/lib/encrypted-secrets" \
  --mount "type=bind,src=$chillbox_build_artifact_vars_file,dst=/var/lib/chillbox-build-artifacts-vars,readonly=true" \
  "$s3_upload_encrypted_secrets_image" || (echo "TODO $0: Ignored error on s3 upload of encrypted secrets.")
