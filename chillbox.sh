#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(realpath "$0")")"

# These variables are updated later, but can be shown in the help output.
chillbox_config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/<instance_name>/<workspace>"
env_config="$chillbox_config_home/env"
chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/<instance_name>/<workspace>"
chillbox_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/chillbox/<instance_name>/<workspace>"

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
  ansible     - Run ansible playbooks or ssh into the server

Files:

  Configuration:
    $env_config
    $chillbox_config_home/terraform-010-infra.private.auto.tfvars
    $chillbox_config_home/terraform-020-chillbox.private.auto.tfvars

  Data:
    $chillbox_data_home/encrypted-secrets
    $chillbox_data_home/terraform_state_backup

  State:
    $chillbox_state_home/build_artifact_logs/
    $chillbox_state_home/<other cache files and directories>

HERE
}

show_environment() {
  printf "\n\n%s\n" "INFO $script_name: Environment"
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
    [ "$sub_command" != "ansible" ] && \
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
    md5sum \
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
  printf "\n\n%s\n" "INFO $script_name: Initializing and sourcing Chillbox configuration at $env_config"
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

    fingerprint_sha256_accept_list_tmp="$(mktemp)"

    pub_ssh_key_urls=""
    printf "\n%s\n" "Use the public ssh key from a GitHub username? [y/n]"
    read -r fetch_pub_ssh_from_gh
    if [ "$fetch_pub_ssh_from_gh" = "y" ]; then
      printf "\n%s\n" "Enter GitHub username:"
      read -r gh_username
      # No official documentation of this URL from GitHub; linking to this
      # StackOverflow answer.
      # What is the public URL for the Github public keys
      # https://stackoverflow.com/a/16158737
      gh_public_ssh_key_url="https://github.com/${gh_username}.keys"
      wget "$gh_public_ssh_key_url" -O - \
        | while read -r pub_ssh_key; do
              printf "%s\n" "$(echo "$pub_ssh_key" | ssh-keygen -l -E sha256 -f - || echo "")" >> "$fingerprint_sha256_accept_list_tmp"
          done
      pub_ssh_key_urls="$gh_public_ssh_key_url"
    fi

    pub_ssh_key_files=""
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
      printf "\n%s\n" "Use the public ssh key from $HOME/.ssh/id_rsa.pub ? [y/n]"
      read -r fetch_pub_ssh_from_home
      if [ "$fetch_pub_ssh_from_home" = "y" ]; then
        printf "%s\n" "$(ssh-keygen -l -E sha256 -f "$HOME/.ssh/id_rsa.pub" || echo "")" >> "$fingerprint_sha256_accept_list_tmp"
        pub_ssh_key_files="$HOME/.ssh/id_rsa.pub"
      fi
    fi

    # Generate the ssh key pair that will be used by ansible when connecting to
    # the deployed chillbox server. This will also create the chillbox_local gpg
    # key that encrypts the credentials used for the hosting service
    # (DigitalOcean) and that ssh private key for ansible.
    public_key_for_ansible="$chillbox_config_home/ansible.pem.pub"
    "$project_dir/src/local/init-gnupg-keys.sh" "$public_key_for_ansible"
    printf "%s\n" "$(ssh-keygen -l -E sha256 -f "$public_key_for_ansible" || echo "")" >> "$fingerprint_sha256_accept_list_tmp"

    fingerprint_sha256_accept_list="$(cat "$fingerprint_sha256_accept_list_tmp")"
    rm -f "$fingerprint_sha256_accept_list_tmp"

    cat <<HERE > "$env_config"
# Change the sites artifact URL to be an absolute file path (starting with a '/') or a URL to download from.
# export SITES_ARTIFACT_URL="/absolute/path/to/site1-0.1-example-sites.tar.gz"
# export SITES_ARTIFACT_URL="https://example.test/site1-0.1-example-sites.tar.gz"
# Setting this to 'example' will use the example site in $project_dir/example directory.
export SITES_ARTIFACT_URL="example"

# The PUBLIC_SSH_KEY_LOCATIONS is a list of URLs or absolute file paths to the
# public ssh keys that will be added to the deployed chillbox server.
export PUBLIC_SSH_KEY_LOCATIONS="$pub_ssh_key_urls $pub_ssh_key_files $public_key_for_ansible"

# Only include the public ssh keys that match the fingerprint in the accept
# list. These are compared with the
# ssh-keygen -l -E sha256 -f path-to-public-ssh-key.pub
# command after fetching them.
export PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST="$fingerprint_sha256_accept_list"

# Update these files as needed.
export TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE="$chillbox_config_home/terraform-010-infra.private.auto.tfvars"
export TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE="$chillbox_config_home/terraform-020-chillbox.private.auto.tfvars"
HERE
  fi

  # Variables that are exported from the env config file.
  # TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE
  # TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE
  # PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST
  # PUBLIC_SSH_KEY_LOCATIONS
  # SITES_ARTIFACT_URL
  # shellcheck source=/dev/null
  . "${env_config}"

  if [ ! -f "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE" ] || [ ! -f "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE" ]; then
    test -f "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE" \
      || cp "$project_dir/example/chillbox-config/$WORKSPACE/terraform-010-infra/example-private.auto.tfvars" "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE"
    test -f "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE" \
      || cp "$project_dir/example/chillbox-config/$WORKSPACE/terraform-020-chillbox/example-private.auto.tfvars" "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE"
    printf "\n%s\n" "Example configuration files have been created. The files shown below should be updated using your text editor ($EDITOR)."
    printf "\n\n#### %s\n\n" "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE"
    cat "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE"
    printf "\n\n#### %s\n\n" "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE"
    cat "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE"
    printf "\n\n%s\n" "Edit these now with the below command? [y/n]"
    printf "\n%s\n" "$EDITOR $TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE $TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE"
    read -r confirm_edit_conf_files
    if [ "$confirm_edit_conf_files" = "y" ]; then
      "$EDITOR" "$TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE" "$TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE"
    else
      printf "\n\n%s\n" "Paused script to allow editing the configuration files in a different editor. Resume $script_name now? [y/n]"
      read -r resume_script
      if [ "$resume_script" != "y" ]; then
        exit 0
      fi
    fi
  fi
}

download_file() {
  has_wget="$(command -v wget || echo "")"
  has_wget=""
  has_curl="$(command -v curl || echo "")"
  remote_file_url="$1"
  output_file="$2"
  test -n "$remote_file_url" || (echo "ERROR $script_name: no remote file URL arg (first arg)" && exit 1)
  test -n "$output_file" || (echo "ERROR $script_name: no output file arg (second arg)" && exit 1)
  test ! -e "$output_file" || (echo "ERROR $script_name: output file already exists: $output_file" && exit 1)
  if [ -n "$has_wget" ]; then
    wget -q -O "$output_file" "$remote_file_url" \
      || (rm -f "$output_file" && echo "ERROR $script_name: Failed to download from URL $remote_file_url" && exit 1)
  elif [ -n "$has_curl" ]; then
    curl --location --output "$output_file" --silent --show-error --fail "$remote_file_url" \
      || (rm -f "$output_file" && echo "ERROR $script_name: Failed to download from URL $remote_file_url" && exit 1)
  else
    echo "ERROR $script_name: No wget or curl commands found."
    exit 1
  fi
}

create_example_site_tar_gz() {
  # UPKEEP due: "2023-05-05" label: "chillbox example site (site1)" interval: "+4 months"
  # https://github.com/jkenlooper/chillbox-example-site1/releases
  example_site_version="0.1.0-alpha.8"

  printf "\n\n%s\n" "INFO $script_name: Create example sites artifact to use."
  printf '%s\n' "Deploy using the example sites artifact? [y/n]"
  read -r confirm_using_example_sites_artifact
  if [ "${confirm_using_example_sites_artifact}" != "y" ]; then
    echo "Update the SITES_ARTIFACT_URL variable in $env_config to not be set to 'example'."
    echo "Exiting"
    exit 2
  fi
  echo "INFO $script_name: Continuing to use example sites artifact."
  tmp_example_sites_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_example_sites_dir"' EXIT
  example_sites_version="$(make --silent --directory="$project_dir" --no-print-directory inspect.VERSION)"
  echo "example_sites_version ($example_sites_version)"
  export SITES_ARTIFACT_URL="$tmp_example_sites_dir/chillbox-example-sites-$example_sites_version.tar.gz"
  # Copy and modify the site json release field for this example site so it can
  # be a file path instead of the https://example.test/ URL.
  cp -R "$project_dir/example/sites" "$tmp_example_sites_dir/"
  if [ ! -e "$chillbox_state_home/site1-$example_site_version.tar.gz" ]; then
    echo "INFO $script_name: No local cached copy of example site1. Downloading new one from https://github.com/jkenlooper/chillbox-example-site1/releases"
    download_file \
      "https://github.com/jkenlooper/chillbox-example-site1/releases/download/$example_site_version/site1.tar.gz" \
      "$chillbox_state_home/site1-$example_site_version.tar.gz"
  fi
  echo "INFO $script_name: Updating example site1.site.json to use $chillbox_state_home/site1-$example_site_version.tar.gz"
  jq \
    --arg jq_release_file_path "$chillbox_state_home/site1-$example_site_version.tar.gz" \
    '.release |= $jq_release_file_path' \
    < "$project_dir/example/sites/site1.site.json" \
    > "$tmp_example_sites_dir/sites/site1.site.json"
  tar c -z -f "$SITES_ARTIFACT_URL" -C "$tmp_example_sites_dir" sites
}

validate_environment_vars() {
  printf "\n\n%s\n" "INFO $script_name: Validating environment variables."
  test -n "${SITES_ARTIFACT_URL}" || (echo "ERROR $script_name: SITES_ARTIFACT_URL variable is empty" && exit 1)
  test -n "${TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE:-}" \
    || (echo "ERROR $script_name: The environment variable: TERRAFORM_INFRA_PRIVATE_AUTO_TFVARS_FILE has not been set in $env_config. See the default file in the tests directory: '$project_dir/example/chillbox-config/$WORKSPACE/terraform-010-infra/example-private.auto.tfvars'." && exit 1)
  test -n "${TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE:-}" \
    || (echo "ERROR $script_name: The environment variable: TERRAFORM_CHILLBOX_PRIVATE_AUTO_TFVARS_FILE has not been set in $env_config.  See the default file in the tests directory: '$project_dir/example/chillbox-config/$WORKSPACE/terraform-020-chillbox/example-private.auto.tfvars'." && exit 1)
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
  printf "\n\n%s\n" "INFO $script_name: Build artifacts locally for sites artifact $SITES_ARTIFACT_URL"
  mkdir -p "$chillbox_state_home"

sites_artifact="$(basename "${SITES_ARTIFACT_URL}")"
sites_artifact_file="$chillbox_state_home/$sites_artifact"

  # The artifacts are built locally by executing the src/local/build-artifacts.sh.
  SITES_ARTIFACT=""
  CHILLBOX_ARTIFACT=""
  SITES_MANIFEST=""
  build_artifacts_log_file=""
  output_env="$(mktemp)"
  "${project_dir}/src/local/build-artifacts.sh" -s "$SITES_ARTIFACT_URL" -o "$output_env" || (echo "ERROR $script_name: The build-artifacts.sh failed. Removing the $sites_artifact_file if it exists to ensure a clean build." && rm -f "$sites_artifact_file" && exit 1)
  eval "$(jq -r '@sh "
      export SITES_ARTIFACT=\(.sites_artifact)
      export CHILLBOX_ARTIFACT=\(.chillbox_artifact)
      export SITES_MANIFEST=\(.sites_manifest)
      export build_artifacts_log_file=\(.log_file)
      "' "$output_env")"
  rm -f "$output_env"

  test -n "$build_artifacts_log_file" || (echo "ERROR $script_name: See the log file." && exit 1)
  echo "See build artifacts log file: $build_artifacts_log_file"

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
  printf "\n\n%s\n" "INFO $script_name: Verify that the artifacts that were built have met the service contracts before continuing."
  "$project_dir/src/local/verify-sites-artifact.sh"
}

generate_site_domains_file() {
  printf "\n\n%s\n" "INFO $script_name: Create site domains file site_domains.auto.tfvars.json"
  dist_sites_dir="$chillbox_state_home/sites"
  mkdir -p "$dist_sites_dir"

  "$project_dir/src/local/generate-site_domains_auto_tfvars.sh"
}

update_ssh_keys_auto_tfvars() {
  printf "\n\n%s\n" "INFO $script_name: Update public ssh keys file developer-public-ssh-keys.auto.tfvars.json"

  "$project_dir/src/local/update-public-ssh-keys-auto-tfvars.sh"
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
# Shift the sub_command off the $@ so any other args can be passed down to other
# commands.
test "$1" != "$sub_command" || shift 1

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
  printf "\n\n%s\n" "WARNING $script_name: Using the example sites artifact."
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

  # Only need to update the public ssh keys if there is a chance that the
  # chillbox server will be modified.
  update_ssh_keys_auto_tfvars

  printf "\n\n%s\n" "INFO $script_name: Dropping into terraform container with '$sub_command' sub command."
  "$project_dir/src/local/terra.sh" "$sub_command"

  # Always run the bootstrap playbook for ansible to init the chillbox server if
  # it hasn't been done yet.
  if [ "$sub_command" = "apply" ]; then
    "$project_dir/src/local/ansible.sh" /usr/local/src/chillbox-ansible/bin/doit.sh -s playbook -- playbooks/bootstrap-chillbox-init-credentials.playbook.yml
  elif [ "$sub_command" = "interactive" ]; then
    "$project_dir/src/local/ansible.sh"
  fi

elif [ "$sub_command" = "clean" ]; then
  printf "\n\n%s\n" "INFO $script_name: Executing '$sub_command' sub command."
  "$project_dir/src/local/clean.sh" -h
  "$project_dir/src/local/clean.sh"

elif [ "$sub_command" = "pull" ]; then
  printf "\n\n%s\n" "INFO $script_name: Executing '$sub_command' sub command to pull terraform state."
  "$project_dir/src/local/pull-terraform-tfstate.sh"

elif [ "$sub_command" = "push" ]; then
  printf "\n\n%s\n" "INFO $script_name: Executing '$sub_command' sub command to push terraform state."
  "$project_dir/src/local/push-terraform-tfstate.sh"

elif [ "$sub_command" = "secrets" ]; then
  printf "\n\n%s\n" "INFO $script_name: Executing '$sub_command' sub command to encrypt and upload secrets."
  "$project_dir/src/local/encrypt-and-upload-secrets.sh" -h
  "$project_dir/src/local/encrypt-and-upload-secrets.sh"

elif [ "$sub_command" = "ansible" ]; then
  # TODO Maybe show a list of playbooks and select which one to run?
  # The default command to run in the ansible container is to bootstrap.

  "$project_dir/src/local/ansible.sh" "$@"

else
  echo "ERROR $script_name: the sub command '$sub_command' was not handled."
  exit 1
fi
