#!/usr/bin/env sh

set -o errexit

project_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"
encrypted_secrets_dir="$project_dir/encrypted_secrets"
gpg_pubkey_dir="$project_dir/gpg_pubkey"

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

# Allow setting defaults from an env file
ENV_CONFIG=${1:-"$project_dir/.env"}
# shellcheck source=/dev/null
test -f "${ENV_CONFIG}" && . "${ENV_CONFIG}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $script_name: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

# Lowercase the INFRA_CONTAINER var since it isn't exported.
infra_container="chillbox-terraform-010-infra-$WORKSPACE"

test -e "$project_dir/.build-artifacts-vars" || (echo "ERROR $script_name: No $project_dir/.build-artifacts-vars file found. Should run the ./terra.sh script first to build artifacts." && exit 1)
SITES_ARTIFACT=""
SITES_MANIFEST=""
# shellcheck source=/dev/null
. "$project_dir/.build-artifacts-vars"

sites_artifact_file="$project_dir/dist/$SITES_ARTIFACT"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -e "${sites_artifact_file}" || (echo "ERROR $script_name: No file found at '$sites_artifact_file'." && exit 1)

sites_manifest_file="$project_dir/dist/$SITES_MANIFEST"
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)
test -e "${sites_manifest_file}" || (echo "ERROR $script_name: No sites manifest file found at '$sites_manifest_file'." && exit 1)

# build the container
# run the container to download the gpg_pubkey files
# Back on the host; build and run the services secrets_export_dockerfile
# build and run the container to upload the encrypted secrets
# Sleeper image needs no context.
sleeper_image="chillbox-sleeper"
docker image rm "$sleeper_image" || printf ""
export DOCKER_BUILDKIT=1
< "$project_dir/src/sleeper.Dockerfile" \
  docker build \
    -t "$sleeper_image" \
    -

s3_wrapper_image="chillbox-s3-wrapper-$WORKSPACE:latest"
docker image rm "$s3_wrapper_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "$s3_wrapper_image" \
  -f "${project_dir}/src/s3-wrapper.Dockerfile" \
  "${project_dir}"

s3_download_gpg_pubkeys_image="chillbox-s3-download-gpg_pubkeys-$WORKSPACE"
s3_download_gpg_pubkeys_container="chillbox-s3-download-gpg_pubkeys-$WORKSPACE"
docker rm "${s3_download_gpg_pubkeys_container}" || printf ""
docker image rm "$s3_download_gpg_pubkeys_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "$s3_download_gpg_pubkeys_image" \
  -f "${project_dir}/src/s3-download-gpg_pubkeys.Dockerfile" \
  "${project_dir}"

rm -rf "$gpg_pubkey_dir"
mkdir -p "$gpg_pubkey_dir"
docker run \
  -i --tty \
  --rm \
  --name "$s3_download_gpg_pubkeys_container" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/home/dev/.aws,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=bind,src=$gpg_pubkey_dir,dst=/var/lib/gpg_pubkey" \
  --entrypoint="" \
  "$s3_download_gpg_pubkeys_image" _download_gpg_pubkeys.sh || (echo "TODO $0: Ignored error on s3 download of gpg pubkeys." && gpg --yes --armor --output "$gpg_pubkey_dir/chillbox.gpg" --export "chillbox")

echo "INFO: Adding temporary local gpg pubkey"
gpg --yes --armor --output "$gpg_pubkey_dir/chillbox-temp-local.gpg" --export "chillbox-temp-local"

tmp_sites_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_sites_dir"
}
trap cleanup EXIT


tar x -f "$sites_artifact_file" -C "$tmp_sites_dir" sites
chmod --recursive u+rw "$tmp_sites_dir"

site_json_files="$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')"
for site_json in $site_json_files; do
  slugname="$(basename "$site_json" .site.json)"
  version="$(jq -r '.version' "$site_json")"

  services="$(jq -c '.services // [] | .[]' "$site_json")"
  test -n "${services}" || continue
  for service_obj in $services; do
    test -n "${service_obj}" || continue
    secrets_config="$(echo "$service_obj" | jq -r '.secrets_config // ""')"
    test -n "$secrets_config" || continue
    service_handler="$(echo "$service_obj" | jq -r '.handler')"
    secrets_export_dockerfile="$(echo "$service_obj" | jq -r '.secrets_export_dockerfile // ""')"
    test -n "$secrets_export_dockerfile" || (echo "ERROR: No secrets_export_dockerfile value set in services, yet secrets_config is defined. $slugname - $service_obj" && exit 1)
    encrypted_secret_file="$encrypted_secrets_dir/$slugname/$service_handler/${secrets_config}.asc"
    encrypted_secret_service_dir="$(dirname "$encrypted_secret_file")"

    mkdir -p "$encrypted_secret_service_dir"

    if [ -e "$encrypted_secret_file" ]; then
      echo "The encrypted file for $slugname $service_handler already exists: $encrypted_secret_file"
      echo "Replace this file? y/n"
      read -r replace_secret_file
      test "$replace_secret_file" = "y" || continue
    fi
    rm -f "$encrypted_secret_file"

    tmp_service_dir="$(mktemp -d)"
    tar x -z -f "$project_dir/dist/$slugname/$slugname-$version.artifact.tar.gz" -C "$tmp_service_dir" "$slugname/${service_handler}"

    test -e "$tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile" || (echo "ERROR: No secrets export dockerfile extracted at path: $tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile" && exit 1)

    service_image_name="$slugname-$version-$service_handler-$WORKSPACE"
    tmp_container_name="$(basename "$tmp_service_dir")-$slugname-$version-$service_handler"
    tmpfs_dir="/run/tmp/$service_image_name"
    service_persistent_dir="/var/lib/$slugname-$service_handler/$WORKSPACE"
    chillbox_gpg_pubkey_dir="/var/lib/chillbox_gpg_pubkey"

    set -x
    docker image rm "$service_image_name" || printf ""
    export DOCKER_BUILDKIT=1
    docker build \
      --build-arg SECRETS_CONFIG="$secrets_config" \
      --build-arg WORKSPACE="${WORKSPACE}" \
      --build-arg CHILLBOX_GPG_PUBKEY_DIR="$chillbox_gpg_pubkey_dir" \
      --build-arg TMPFS_DIR="$tmpfs_dir" \
      --build-arg SERVICE_PERSISTENT_DIR="$service_persistent_dir" \
      --build-arg SLUGNAME="$slugname" \
      --build-arg VERSION="$version" \
      --build-arg SERVICE_HANDLER="$service_handler" \
      -t "$service_image_name" \
      -f "$tmp_service_dir/$slugname/$service_handler/$secrets_export_dockerfile" \
      "$tmp_service_dir/$slugname/$service_handler/"

    docker run \
      -i --tty \
      --rm \
      --name "$tmp_container_name" \
      --mount "type=tmpfs,dst=$tmpfs_dir" \
      --mount "type=volume,src=chillbox-service-persistent-dir-var-lib-$slugname-$service_handler-$WORKSPACE,dst=$service_persistent_dir" \
      --mount "type=bind,src=$gpg_pubkey_dir,dst=$chillbox_gpg_pubkey_dir,readonly=true" \
      "$service_image_name"

    docker run \
      -d \
      --name "$tmp_container_name-sleeper" \
      --mount "type=volume,src=chillbox-service-persistent-dir-var-lib-$slugname-$service_handler-$WORKSPACE,dst=$service_persistent_dir" \
      "$sleeper_image"
    docker cp "$tmp_container_name-sleeper:$service_persistent_dir/encrypted_secrets/" "$encrypted_secret_service_dir/"
    docker stop --time 0 "$tmp_container_name-sleeper" || printf ""
    docker rm "$tmp_container_name-sleeper" || printf ""

  done

done

echo "TODO"
exit 0
aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  --recursive \
  "$encrypted_secrets_dir" \
  "s3://${ARTIFACT_BUCKET_NAME}/chillbox/"
