
#!/usr/bin/env sh

set -o errexit

project_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"
encrypted_secrets_dir="$project_dir/encrypted_secrets"
chillbox_gpg_key_file="$encrypted_secrets_dir/chillbox.gpg"

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

SITES_ARTIFACT="${SITES_ARTIFACT:-}"
sites_artifact_file="$project_dir/dist/$SITES_ARTIFACT"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -e "${sites_artifact_file}" || (echo "ERROR $script_name: No file found at '$sites_artifact_file'." && exit 1)

SITES_MANIFEST="${SITES_MANIFEST:-}"
sites_manifest_file="$project_dir/dist/$SITES_MANIFEST"
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)
test -e "${sites_manifest_file}" || (echo "ERROR $script_name: No sites manifest file found at '$sites_manifest_file'." && exit 1)

mkdir -p $encrypted_secrets_dir/gpg_pubkey/
aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  --recursive \
  "s3://${ARTIFACT_BUCKET_NAME}/chillbox/gpg_pubkey/" \
  "$encrypted_secrets_dir/gpg_pubkey/"

tmp_sites_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_sites_dir"
}
trap cleanup EXIT


tar x -f "$sites_artifact_file" -C "$tmp_sites_dir" sites
chmod --recursive u+rw "$tmp_sites_dir"


sites="$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')"

for site_json in $sites; do
  site_json_file="$(basename "$site_json")"
  slugname="$(basename "$site_json" .site.json)"
  version="$(jq -r '.version' "$site_json")"

  jq -c '.services // [] | .[]' "$site_json_file" \
    | while read -r service_obj; do
        test -n "${service_obj}" || continue
        secrets_config="$(echo "$service_obj" | jq -r '.secrets_config // ""')"
        test -n "$secrets_config" || continue
        service_handler="$(echo "$service_obj" | jq -r '.handler')"
        secrets_export_dockerfile="$(echo "$service_obj" | jq -r '.secrets_export_dockerfile')"
        encrypted_secret_file="$encrypted_secrets_dir/$slugname/$service_handler/${secrets_config}.asc"
        encrypted_secret_service_dir="$(dirname "$encrypted_secret_file")"

        mkdir -p "$encrypted_secret_service_dir"

        if [ -e "$encrypted_secret_file" ]; then
          echo "The encrypted file for $slugname $service_handler already exists: $encrypted_secret_file"
          echo "Replace this file? y/n"
          read replace_secret_file
          test "$replace_secret_file" = "y" || continue
        fi
        rm -f "$encrypted_secret_file"

        tmp_service_dir="$(mktemp -d)"
        tar x -z -f "$project_dir/dist/$slugname/$slugname-$version.artifact.tar.gz" -C "$tmp_service_dir" "$slugname/${service_handler}"

        service_image_name="$slugname-$version-$service_handler-$WORKSPACE"
        tmp_container_name="$(basename "$tmp_service_dir")-$slugname-$version-$service_handler"
        tmpfs_dir="/run/tmp/$service_image_name"
        service_persistent_dir="/var/lib/$slugname-$service_handler/$WORKSPACE"
        chillbox_gpg_pubkey_dir="/var/lib/chillbox_gpg_pubkey"

        docker rm "$tmp_container_name" || printf ""
        docker image rm "$service_image_name" || printf ""
        export DOCKER_BUILDKIT=1
        docker build \
          --build-arg SECRETS_CONFIG="$secrets_config" \
          --build-arg WORKSPACE="${WORKSPACE}" \
          --build-arg CHILLBOX_GPG_PUBKEY_DIR="$chillbox_gpg_pubkey_dir" \
          --build-arg TMPFS_DIR="$tmpfs_dir"
          --build-arg SERVICE_PERSISTENT_DIR="$service_persistent_dir"
          --build-arg SLUGNAME="$slugname"
          --build-arg VERSION="$version"
          --build-arg SERVICE_HANDLER="$service_handler"
          -t "$service_image_name" \
          -f "$tmp_service_dir/$service_handler/$secrets_export_dockerfile" \
          "$tmp_service_dir/$service_handler/"

        docker run \
          -i --tty \
          --name "$tmp_container_name" \
          --mount "type=tmpfs,dst=$tmpfs_dir" \
          --mount "type=volume,src=chillbox-service-persistent-dir-var-lib-$slugname-$service_handler-$WORKSPACE,dst=$service_persistent_dir" \
          --mount "type=bind,src=$encrypted_secrets_dir/gpg_pubkey,dst=$chillbox_gpg_pubkey_dir,readonly=true" \
          "$service_image_name"
        docker cp "$tmp_container_name:$service_persistent_dir/encrypted_secrets/" "$encrypted_secret_service_dir/"
        docker rm "$tmp_container_name" || printf ""

      done

done

aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  --recursive \
  "$encrypted_secrets_dir" \
  "s3://${ARTIFACT_BUCKET_NAME}/chillbox/"
