#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HERE

Script to handle chillbox deployments.

Usage:
  $script_name -h
  $script_name [<options>] [<sub-command>]

Options:
  -h                  Show this help message.

  -i <instance_name>  Pass in the name of the chillbox instance.
                      Defaults to the name 'default' if no CHILLBOX_INSTANCE
                      variable is set.

  -w <workspace>      Set the workspace environment.
                      Must be: development, test, acceptance, production
                      Default workspace environment is development if no
                      WORKSPACE variable is set.

Sub commands:
  interactive - Start containers in that mode. This is the default.
  plan        - Passed to the Terraform command inside each container.
  apply       - Passed to the Terraform command inside each container.
  destroy     - Passed to the Terraform command inside each container.
  pull        - Pulls the Terraform state files to the host.
  push        - Pushes the Terraform state files to the Terraform containers.
  clean       - Removes state files that were saved for the instance and workspace.
  secrets     - Encrypt and upload the site secrets to the s3 object storage.

HERE
}

show_environment() {
  cat <<HERE
CHILLBOX_INSTANCE: $CHILLBOX_INSTANCE
WORKSPACE: $WORKSPACE
Environment config file: $env_config
chillbox script directory: $project_dir
HERE
}

check_args_and_environment_vars() {
  if [ "$sub_command" != "interactive" ] && \
    [ "$sub_command" != "plan" ] && \
    [ "$sub_command" != "apply" ] && \
    [ "$sub_command" != "destroy" ] && \
    [ "$sub_command" != "pull" ] && \
    [ "$sub_command" != "push" ] && \
    [ "$sub_command" != "clean" ] && \
    [ "$sub_command" != "secrets" ]; then
    echo "ERROR $script_name: This command ($sub_command) is not supported in this script."
    exit 1
  fi

  test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)
  if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
    echo "ERROR $script_name: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
    exit 1
  fi
}

check_for_required_commands() {
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
}

init_and_source_chillbox_config() {
  mkdir -p "$chillbox_config_home"

  if [ ! -f "${env_config}" ]; then
    # Prompt the user if no environment config file exists in case this was not
    # the desired operation. If this is the first time running this script for the
    # environment; it is helpful to create the files needed.
    echo "INFO $script_name: No $env_config file found."
    printf "\n%s\n" "Create the $env_config file? [y/n]"
    read -r create_default_environment_file
    if [ "$create_default_environment_file" != "y" ]; then
      echo "Exiting since no environment file exists at $env_config."
      exit 2
    fi

    test -f "$chillbox_config_home/terraform-010-infra.private.auto.tfvars" \
      || cp "$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-010-infra/example-private.auto.tfvars" "$chillbox_config_home/terraform-010-infra.private.auto.tfvars"
    test -f "$chillbox_config_home/terraform-020-chillbox.private.auto.tfvars" \
      || cp "$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-020-chillbox/example-private.auto.tfvars" "$chillbox_config_home/terraform-020-chillbox.private.auto.tfvars"
    cat <<HERE > "$env_config"
# Change the sites artifact URL to be an absolute file path (starting with a '/') or a URL to download from.
# export SITES_ARTIFACT_URL="/absolute/path/to/site1-0.1-example-sites.tar.gz"
# export SITES_ARTIFACT_URL="https://example.test/site1-0.1-example-sites.tar.gz"
# Setting this to 'example' will just use the example site in $project_dir
export SITES_ARTIFACT_URL="example"

# Update these files as needed.
export TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE="$chillbox_config_home/terraform-010-infra.private.auto.tfvars"
export TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE="$chillbox_config_home/terraform-020-chillbox.private.auto.tfvars"
HERE
  fi

  # shellcheck source=/dev/null
  . "${env_config}"
}

create_example_site_tar_gz() {
  printf '%s\n' "Deploy using the example sites artifact? [y/n]"
  read -r confirm_using_example_sites_artifact
  test "${confirm_using_example_sites_artifact}" = "y" || (echo "Exiting" && exit 2)
  echo "INFO $script_name: Continuing to use example sites artifact."
  tmp_example_sites_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_example_sites_dir"' EXIT
  example_sites_version="$(make --silent --directory="$project_dir" inspect.VERSION)"
  echo "example_sites_version ($example_sites_version)"
  export SITES_ARTIFACT_URL="$tmp_example_sites_dir/chillbox-example-sites-$example_sites_version.tar.gz"
  # Copy and modify the site json release field for this example site so it can
  # be a file path instead of the https://example.test/ URL.
  cp -R "$project_dir/tests/fixtures/sites" "$tmp_example_sites_dir/"
  site1_version="$(make --silent --directory="$project_dir/tests/fixtures/site1" inspect.VERSION)"
  echo "site1_version ($site1_version)"
  jq \
    --arg jq_release_file_path "$tmp_example_sites_dir/site1-$site1_version.tar.gz" \
    '.release |= $jq_release_file_path' \
    < "$project_dir/tests/fixtures/sites/site1.site.json" \
    > "$tmp_example_sites_dir/sites/site1.site.json"
  tar c -z -f "$SITES_ARTIFACT_URL" -C "$tmp_example_sites_dir" sites
  tar c -z -f "$tmp_example_sites_dir/site1-$site1_version.tar.gz" -C "$project_dir/tests/fixtures" site1
}

validate_environment_vars() {
  test -n "${SITES_ARTIFACT_URL}" || (echo "ERROR $script_name: SITES_ARTIFACT_URL variable is empty" && exit 1)
  test -n "${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE:-}" \
    || (echo "ERROR $script_name: The environment variable: TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE has not been set in $env_config. See the default file in the tests directory: '$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-010-infra/example-private.auto.tfvars'." && exit 1)
  test -n "${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE:-}" \
    || (echo "ERROR $script_name: The environment variable: TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE has not been set in $env_config.  See the default file in the tests directory: '$project_dir/tests/fixtures/example-chillbox-config/$WORKSPACE/terraform-020-chillbox/example-private.auto.tfvars'." && exit 1)
  test -f "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE" \
    || (echo "ERROR $script_name: The environment variable: TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE is set to a file that doesn't exist: $TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE" && exit 1)
  test -f "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE" \
    || (echo "ERROR $script_name: The environment variable: TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE is set to a file that doesn't exist: $TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE" && exit 1)

  if [ "$(basename "$SITES_ARTIFACT_URL" ".tar.gz")" = "$(basename "$SITES_ARTIFACT_URL")" ]; then
    echo "ERROR $script_name: The SITES_ARTIFACT_URL must end with a '.tar.gz' extension."
    exit 1
  fi

  echo "INFO $script_name: Using SITES_ARTIFACT_URL '${SITES_ARTIFACT_URL}'"
  echo "INFO $script_name: Using TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE '${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE}'"
  echo "INFO $script_name: Using TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE '${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE}'"
}

build_artifacts() {
  mkdir -p "$chillbox_state_home"

  # The artifacts are built locally by executing the src/local/build-artifacts.sh.
  echo "INFO $script_name: Build the artifacts"
  SITES_ARTIFACT=""
  CHILLBOX_ARTIFACT=""
  SITES_MANIFEST=""
  eval "$(jq \
    --arg jq_sites_artifact_url "$SITES_ARTIFACT_URL" \
    --null-input '{
      sites_artifact_url: $jq_sites_artifact_url,
  }' | "${project_dir}/src/local/build-artifacts.sh" | jq -r '@sh "
      export SITES_ARTIFACT=\(.sites_artifact)
      export CHILLBOX_ARTIFACT=\(.chillbox_artifact)
      export SITES_MANIFEST=\(.sites_manifest)
      "')"
  test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
  test -n "${CHILLBOX_ARTIFACT}" || (echo "ERROR $script_name: The CHILLBOX_ARTIFACT variable is empty." && exit 1)
  test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)

  chillbox_build_artifact_vars_file="$chillbox_state_home/build-artifacts-vars"
  cat <<HERE > "$chillbox_build_artifact_vars_file"
export SITES_ARTIFACT="$SITES_ARTIFACT"
export CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT"
export SITES_MANIFEST="$SITES_MANIFEST"
HERE
}

verify_built_artifacts() {
  # Verify that the artifacts that were built have met the service contracts before continuing.
  "$project_dir/src/local/verify-sites-artifact.sh"
}

generate_site_domains_file() {
  dist_sites_dir="$chillbox_state_home/sites"
  mkdir -p "$dist_sites_dir"

  "$project_dir/src/local/generate-site_domains_auto_tfvars.sh"
}
workspace="${WORKSPACE:-development}"
chillbox_instance="${CHILLBOX_INSTANCE:-default}"

while getopts "hw:i:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    w) workspace=$OPTARG ;;
    i) chillbox_instance=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))
sub_command=${1:-interactive}

export CHILLBOX_INSTANCE="$chillbox_instance"
export WORKSPACE="$workspace"
chillbox_config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
env_config="$chillbox_config_home/env"
chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

show_environment
check_args_and_environment_vars
check_for_required_commands
init_and_source_chillbox_config

if [ "${SITES_ARTIFACT_URL}" = "example" ]; then
  echo "WARNING $script_name: Using the example sites artifact."
  create_example_site_tar_gz
fi

validate_environment_vars
build_artifacts
verify_built_artifacts
generate_site_domains_file

if [ "$sub_command" = "interactive" ] || \
  [ "$sub_command" = "plan" ] || \
  [ "$sub_command" = "apply" ] || \
  [ "$sub_command" = "destroy" ]; then
  "$project_dir/src/local/terra.sh" "$sub_command"

elif [ "$sub_command" = "clean" ]; then
  "$project_dir/src/local/clean.sh"

elif [ "$sub_command" = "pull" ]; then
  "$project_dir/src/local/pull-terraform-tfstate.sh"

elif [ "$sub_command" = "push" ]; then
  "$project_dir/src/local/push-terraform-tfstate.sh"

elif [ "$sub_command" = "secrets" ]; then
  "$project_dir/src/local/encrypt-and-upload-secrets.sh"

else
  echo "ERROR $script_name: the sub command '$sub_command' was not handled."
  exit 1
fi
