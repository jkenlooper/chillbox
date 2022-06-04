#!/usr/bin/env sh

# Helper script for isolating use of terraform in a container.

set -o errexit

script_name="$(basename "$0")"

for required_command in \
  realpath \
  docker \
  jq \
  make \
  tar \
  ; do
  command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." && exit 1)
done

has_wget="$(command -v wget || echo "")"
has_curl="$(command -v curl || echo "")"
if [ -z "$has_wget" ] && [ -z "$has_curl" ]; then
  echo "WARNING $script_name: Downloading site artifact files require 'wget' or 'curl' commands. Neither were found on this system."
fi

project_dir="$(dirname "$(realpath "$0")")"
terraform_infra_dir="$project_dir/terraform-010-infra"
terraform_chillbox_dir="$project_dir/terraform-020-chillbox"


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

# The WORKSPACE is passed as a build-arg for the images, so make the image and
# container name also have that in their name.
export INFRA_IMAGE="chillbox-terraform-010-infra-$WORKSPACE"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox-$WORKSPACE"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$WORKSPACE"

test -n "${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE:-}" \
  || echo "WARNING $script_name: The environment variable: TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE has not been set; using the default file in tests directory."
test -n "${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE:-}" \
  || echo "WARNING $script_name: The environment variable: TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE has not been set; using the default file in tests directory."
terraform_infra_private_auto_tfvars_file="${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE:-$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-010-infra/example-private.auto.tfvars}"
terraform_chillbox_private_auto_tfvars_file="${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE:-$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-020-chillbox/example-private.auto.tfvars}"

SITES_ARTIFACT_URL=${SITES_ARTIFACT_URL:-"example"}
test -n "${SITES_ARTIFACT_URL}" || (echo "ERROR $script_name: SITES_ARTIFACT_URL variable is empty" && exit 1)
echo "INFO $script_name: Using SITES_ARTIFACT_URL '${SITES_ARTIFACT_URL}'"

# Allow for quickly testing things by using an example site to deploy.
if [ "${SITES_ARTIFACT_URL}" = "example" ]; then
  echo "WARNING $script_name: Using the example sites artifact."
  printf '%s\n' "Deploy using the example sites artifact? [y/n]"
  read -r confirm_using_example_sites_artifact
  test "${confirm_using_example_sites_artifact}" = "y" || (echo "Exiting" && exit 2)
  echo "INFO $script_name: Continuing to use example sites artifact."
  tmp_example_sites_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_example_sites_dir"' EXIT
  example_sites_version="$(cat VERSION)"
  SITES_ARTIFACT_URL="$tmp_example_sites_dir/chillbox-example-sites-$example_sites_version.tar.gz"
  # Copy and modify the site json release field for this example site so it can
  # be a file path instead of the https://example.test/ URL.
  cp -R tests/fixtures/sites "$tmp_example_sites_dir/"
  site1_version="$(make --silent -C tests/fixtures/site1 inspect.VERSION)"
  jq \
    --arg jq_release_file_path "$tmp_example_sites_dir/site1-$site1_version.tar.gz" \
    '.release |= $jq_release_file_path' \
    < "$project_dir/tests/fixtures/sites/site1.site.json" \
    > "$tmp_example_sites_dir/sites/site1.site.json"
  tar c -z -f "$SITES_ARTIFACT_URL" -C "$tmp_example_sites_dir" sites
  tar c -z -f "$tmp_example_sites_dir/site1-$site1_version.tar.gz" -C "$project_dir/tests/fixtures" site1
fi

if [ "$(basename "$SITES_ARTIFACT_URL" ".tar.gz")" = "$(basename "$SITES_ARTIFACT_URL")" ]; then
  echo "ERROR $script_name: The SITES_ARTIFACT_URL must end with a '.tar.gz' extension."
  exit 1
fi

# The artifacts are built locally by executing the local-bin/build-artifacts.sh.
echo "INFO $script_name: Build the artifacts"
SITES_ARTIFACT=""
CHILLBOX_ARTIFACT=""
SITES_MANIFEST=""
eval "$(jq \
  --arg jq_sites_artifact_url "$SITES_ARTIFACT_URL" \
  --null-input '{
    sites_artifact_url: $jq_sites_artifact_url,
}' | "${project_dir}/local-bin/build-artifacts.sh" | jq -r '@sh "
    export SITES_ARTIFACT=\(.sites_artifact)
    export CHILLBOX_ARTIFACT=\(.chillbox_artifact)
    export SITES_MANIFEST=\(.sites_manifest)
    "')"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -n "${CHILLBOX_ARTIFACT}" || (echo "ERROR $script_name: The CHILLBOX_ARTIFACT variable is empty." && exit 1)
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)

# Verify that the artifacts that were built have met the service contracts before continuing.
SITES_ARTIFACT="$SITES_ARTIFACT" SITES_MANIFEST="$SITES_MANIFEST" "$project_dir/local-bin/verify-sites-artifact.sh"

cat <<HERE > .build-artifacts-vars
export SITES_ARTIFACT="$SITES_ARTIFACT"
export CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT"
export SITES_MANIFEST="$SITES_MANIFEST"
HERE

"$project_dir/local-bin/_docker_build_terraform-010-infra.sh"

cleanup_run_tmp_secrets() {
  docker stop "${INFRA_CONTAINER}" 2> /dev/null || printf ""
  docker rm "${INFRA_CONTAINER}" 2> /dev/null || printf ""
  docker stop "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""
  docker rm "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""

  # TODO support systems other then Linux that can't use a tmpfs mount. Will
  # need to always run a volume rm command each time the container stops to
  # simulate how tmpfs works on Linux.
  #docker volume rm "chillbox-terraform-run-tmp-secrets--${WORKSPACE}" || echo "ERROR $script_name: Failed to remove docker volume 'chillbox-terraform-run-tmp-secrets--${WORKSPACE}'. Does it exist?"
}
trap cleanup_run_tmp_secrets EXIT

echo "infra container $INFRA_CONTAINER"
docker run \
  -i --tty \
  --name "${INFRA_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --entrypoint="" \
  "$INFRA_IMAGE" doterra-init.sh
docker cp "${INFRA_CONTAINER}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" "${terraform_infra_dir}/"

# TODO It may be useful to only allow secret files to be passed in if they were
# encrypted with this public key first. This way the tfstate backup file stored
# on the local machine could be encrypted first before it was sent back.
#test -f "${project_dir}/chillbox_doterra__${WORKSPACE}.gpg" && rm "${project_dir}/chillbox_doterra__${WORKSPACE}.gpg"
#docker cp "${INFRA_CONTAINER}:/usr/local/src/chillbox-terraform/chillbox_doterra__${WORKSPACE}.gpg" "${project_dir}/"

docker rm "${INFRA_CONTAINER}"

# TODO change the command to be 'doterra.sh $terraform_command' instead of 'sh'
docker run \
  -i --tty \
  --rm \
  --name "${INFRA_CONTAINER}" \
  --hostname "${INFRA_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
  --mount "type=bind,src=${terraform_infra_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_infra_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_infra_private_auto_tfvars_file},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --entrypoint="" \
  "$INFRA_IMAGE" sh

# Start the chillbox terraform

"$project_dir/local-bin/_docker_build_terraform-020-chillbox.sh"

docker run \
  --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
  --user dev \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/user_data_chillbox.sh.tftpl,dst=/usr/local/src/chillbox-terraform/user_data_chillbox.sh.tftpl" \
  --mount "type=bind,src=${terraform_chillbox_private_auto_tfvars_file},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  "$TERRAFORM_CHILLBOX_IMAGE" init
docker cp "${TERRAFORM_CHILLBOX_CONTAINER}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" "${terraform_chillbox_dir}/"
docker rm "${TERRAFORM_CHILLBOX_CONTAINER}"

docker run \
  -i --tty \
  --rm \
  --name "${TERRAFORM_CHILLBOX_CONTAINER}" \
  --hostname "${TERRAFORM_CHILLBOX_CONTAINER}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/home/dev/.aws,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=volume,src=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
  --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/user_data_chillbox.sh.tftpl,dst=/usr/local/src/chillbox-terraform/user_data_chillbox.sh.tftpl" \
  --mount "type=bind,src=${terraform_chillbox_private_auto_tfvars_file},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --entrypoint="" \
  "$TERRAFORM_CHILLBOX_IMAGE" sh
