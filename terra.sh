#!/usr/bin/env sh

# Helper script for isolating use of terraform in a container.

set -o errexit

for required_command in \
  realpath \
  docker \
  jq \
  make \
  tar \
  ; do
  command -v "$required_command" > /dev/null || (echo "ERROR $0: Requires '$required_command' command." && exit 1)
done

has_wget="$(command -v wget || echo "")"
has_curl="$(command -v curl || echo "")"
if [ -z "$has_wget" ] && [ -z "$has_curl" ]; then
  echo "WARNING $0: Downloading site artifact files require 'wget' or 'curl' commands. Neither were found on this system."
fi

project_dir="$(dirname "$(realpath "$0")")"
terraform_infra_dir="$project_dir/terraform-010-infra"
terraform_chillbox_dir="$project_dir/terraform-020-chillbox"

# Allow setting defaults from an env file
ENV_CONFIG=${1:-"$project_dir/.env"}
# shellcheck source=/dev/null
test -f "${ENV_CONFIG}" && . "${ENV_CONFIG}"

WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  echo "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

test -n "${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE:-}" \
  || echo "WARNING $0: The environment variable: TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE has not been set; using the default file in tests directory."
test -n "${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE:-}" \
  || echo "WARNING $0: The environment variable: TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE has not been set; using the default file in tests directory."
terraform_infra_private_auto_tfvars_file="${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE:-$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-010-infra/example-private.auto.tfvars}"
terraform_chillbox_private_auto_tfvars_file="${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE:-$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-020-chillbox/example-private.auto.tfvars}"

# UPKEEP due: "2022-07-12" label: "Alpine Linux custom image" interval: "+3 months"
# Create this file by following instructions at jkenlooper/alpine-droplet
ALPINE_CUSTOM_IMAGE=${ALPINE_CUSTOM_IMAGE:-"https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-04-13-0434/alpine-virt-image-2022-04-13-0434.qcow2.bz2"}
test -n "${ALPINE_CUSTOM_IMAGE}" || (echo "ERROR $0: ALPINE_CUSTOM_IMAGE variable is empty" && exit 1)
echo "INFO $0: Using ALPINE_CUSTOM_IMAGE '${ALPINE_CUSTOM_IMAGE}'"
ALPINE_CUSTOM_IMAGE_CHECKSUM=${ALPINE_CUSTOM_IMAGE_CHECKSUM:-"f8aa090e27509cc9e9cb57f6ad16d7b3"}
test -n "${ALPINE_CUSTOM_IMAGE_CHECKSUM}" || (echo "ERROR $0: ALPINE_CUSTOM_IMAGE_CHECKSUM variable is empty" && exit 1)
echo "INFO $0: Using ALPINE_CUSTOM_IMAGE_CHECKSUM '${ALPINE_CUSTOM_IMAGE_CHECKSUM}'"


SITES_ARTIFACT_URL=${SITES_ARTIFACT_URL:-"example"}
test -n "${SITES_ARTIFACT_URL}" || (echo "ERROR $0: SITES_ARTIFACT_URL variable is empty" && exit 1)
echo "INFO $0: Using SITES_ARTIFACT_URL '${SITES_ARTIFACT_URL}'"

# Allow for quickly testing things by using an example site to deploy.
if [ "${SITES_ARTIFACT_URL}" = "example" ]; then
  echo "WARNING $0: Using the example sites artifact."
  printf '%s\n' "Deploy using the example sites artifact? [y/n]"
  read -r confirm_using_example_sites_artifact
  test "${confirm_using_example_sites_artifact}" = "y" || (echo "Exiting" && exit 2)
  echo "INFO $0: Continuing to use example sites artifact."
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
  echo "ERROR $0: The SITES_ARTIFACT_URL must end with a '.tar.gz' extension."
  exit 1
fi

# The artifacts are built locally by executing the local-bin/build-artifacts.sh.
echo "INFO $0: Build the artifacts"
SITES_ARTIFACT=""
CHILLBOX_ARTIFACT=""
SITES_MANIFEST=""
eval "$(jq \
  --arg jq_sites_artifact_url "$SITES_ARTIFACT_URL" \
  --null-input '{
    sites_artifact_url: $jq_sites_artifact_url,
}' | "${project_dir}/local-bin/build-artifacts.sh" | jq -r '@sh "
    SITES_ARTIFACT=\(.sites_artifact)
    CHILLBOX_ARTIFACT=\(.chillbox_artifact)
    SITES_MANIFEST=\(.sites_manifest)
    "')"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $0: The SITES_ARTIFACT variable is empty." && exit 1)
test -n "${CHILLBOX_ARTIFACT}" || (echo "ERROR $0: The CHILLBOX_ARTIFACT variable is empty." && exit 1)
test -n "${SITES_MANIFEST}" || (echo "ERROR $0: The SITES_MANIFEST variable is empty." && exit 1)


infra_image="chillbox-$(basename "${terraform_infra_dir}")"
infra_container="chillbox-$(basename "${terraform_infra_dir}")"
docker rm "${infra_container}" || printf ""
docker image rm "$infra_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "$infra_image" \
  -f "${project_dir}/terraform-010-infra.Dockerfile" \
  "${project_dir}"

cleanup_run_tmp_secrets() {
  docker stop "${infra_container}" 2> /dev/null || printf ""
  docker rm "${infra_container}" 2> /dev/null || printf ""
  docker stop "${terraform_chillbox_container}" 2> /dev/null || printf ""
  docker rm "${terraform_chillbox_container}" 2> /dev/null || printf ""
  #docker volume rm "chillbox-terraform-run-tmp-secrets--${WORKSPACE}" || echo "ERROR $0: Failed to remove docker volume 'chillbox-terraform-run-tmp-secrets--${WORKSPACE}'. Does it exist?"
}
trap cleanup_run_tmp_secrets EXIT

docker run \
  -i --tty \
  --name "${infra_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-tfstate--${WORKSPACE},dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --entrypoint="" \
  "$infra_image" doterra-init.sh
docker cp "${infra_container}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" "${terraform_infra_dir}/"
# TODO No longer need to copy the gpg key from this container. The private key
# to decrypt site secrets only lives on the chillbox server. The public key for
# that is shared on the artifacts bucket.
#test -f "${project_dir}/chillbox_doterra__${WORKSPACE}.gpg" && rm "${project_dir}/chillbox_doterra__${WORKSPACE}.gpg"
#docker cp "${infra_container}:/usr/local/src/chillbox-terraform/chillbox_doterra__${WORKSPACE}.gpg" "${project_dir}/"
docker rm "${infra_container}"

docker run \
  -i --tty \
  --rm \
  --name "${infra_container}" \
  --hostname "${infra_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-tfstate--${WORKSPACE},dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=false" \
  --mount "type=bind,src=${terraform_infra_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_infra_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_infra_private_auto_tfvars_file},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --entrypoint="" \
  "$infra_image" sh

# Start the chillbox terraform

terraform_chillbox_image="chillbox-$(basename "${terraform_chillbox_dir}")"
terraform_chillbox_container="chillbox-$(basename "${terraform_chillbox_dir}")"
docker rm "${terraform_chillbox_container}" || printf ""
docker image rm "$terraform_chillbox_image" || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --build-arg ALPINE_CUSTOM_IMAGE="${ALPINE_CUSTOM_IMAGE}" \
  --build-arg ALPINE_CUSTOM_IMAGE_CHECKSUM="${ALPINE_CUSTOM_IMAGE_CHECKSUM}" \
  --build-arg SITES_ARTIFACT="${SITES_ARTIFACT}" \
  --build-arg CHILLBOX_ARTIFACT="${CHILLBOX_ARTIFACT}" \
  --build-arg SITES_MANIFEST="${SITES_MANIFEST}" \
  --build-arg WORKSPACE="${WORKSPACE}" \
  -t "${terraform_chillbox_image}" \
  -f "${project_dir}/terraform-020-chillbox.Dockerfile" \
  "${project_dir}"

docker run \
  --name "${terraform_chillbox_container}" \
  --user dev \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-${terraform_chillbox_container}-tfstate--${WORKSPACE},dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=volume,src=chillbox-${terraform_chillbox_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
  --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/user_data_chillbox.sh.tftpl,dst=/usr/local/src/chillbox-terraform/user_data_chillbox.sh.tftpl" \
  --mount "type=bind,src=${terraform_chillbox_private_auto_tfvars_file},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  "$terraform_chillbox_image" init
docker cp "${terraform_chillbox_container}:/usr/local/src/chillbox-terraform/.terraform.lock.hcl" "${terraform_chillbox_dir}/"
docker rm "${terraform_chillbox_container}"

docker run \
  -i --tty \
  --rm \
  --name "${terraform_chillbox_container}" \
  --hostname "${terraform_chillbox_container}" \
  -e WORKSPACE="${WORKSPACE}" \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/home/dev/.aws,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-terraform-dev-dotgnupg--${WORKSPACE},dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-dev-terraformdotd--${WORKSPACE},dst=/home/dev/.terraform.d,readonly=false" \
  --mount "type=volume,src=chillbox-${terraform_chillbox_container}-tfstate--${WORKSPACE},dst=/usr/local/src/chillbox-terraform/terraform.tfstate.d,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--${WORKSPACE},dst=/var/lib/doterra,readonly=false" \
  --mount "type=volume,src=chillbox-${infra_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=volume,src=chillbox-${terraform_chillbox_container}-var-lib--${WORKSPACE},dst=/var/lib/terraform-020-chillbox,readonly=false" \
  --mount "type=bind,src=${terraform_chillbox_dir}/chillbox.tf,dst=/usr/local/src/chillbox-terraform/chillbox.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/variables.tf,dst=/usr/local/src/chillbox-terraform/variables.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/main.tf,dst=/usr/local/src/chillbox-terraform/main.tf" \
  --mount "type=bind,src=${terraform_chillbox_dir}/user_data_chillbox.sh.tftpl,dst=/usr/local/src/chillbox-terraform/user_data_chillbox.sh.tftpl" \
  --mount "type=bind,src=${terraform_chillbox_private_auto_tfvars_file},dst=/usr/local/src/chillbox-terraform/private.auto.tfvars" \
  --entrypoint="" \
  "$terraform_chillbox_image" sh
