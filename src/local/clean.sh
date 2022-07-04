#!/usr/bin/env sh

set -o errexit

usage() {
  cat <<HERE
Cleans the state data associated with chillbox instance and workspace.
This will remove the container volumes and the chillbox local state files.

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

# echo is bad... mmm k

export CHILLBOX_INSTANCE="${CHILLBOX_INSTANCE:-default}"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (printf '\n%s\n' "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  printf '\n%s\n' "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

chillbox_state_dir="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

state_file_list="$(find "$chillbox_state_dir" -type f)"
if [ -z "$state_file_list" ]; then
  printf '\n%s\n' "No cache files found to delete in chillbox instance '$CHILLBOX_INSTANCE' and workspace '$WORKSPACE'."
else
  printf '\n%s\n' "The $0 script will delete the cache files in the directory '$chillbox_state_dir' for the chillbox instance '$CHILLBOX_INSTANCE' and workspace '$WORKSPACE'."
  printf '\n%s\n' "$state_file_list"
  printf '\n%s\n' "Delete the cache files in the $chillbox_state_dir directory? [y/n]"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    find "$chillbox_state_dir" -type f -delete
  else
    printf '\n%s\n' "Skipping deletion of cache files in $chillbox_state_dir directory."
  fi
fi

env_config="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE/env"
if [ -f "${env_config}" ]; then
  # shellcheck source=/dev/null
  . "${env_config}"
else
  echo "ERROR $0: No $env_config file found."
  exit 1
fi

# The WORKSPACE is passed as a build-arg for the images, so make the image and
# container name also have that in their name.
export INFRA_IMAGE="chillbox-terraform-010-infra:latest"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox:latest"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$CHILLBOX_INSTANCE-$WORKSPACE"


printf '\n%s\n' "The $0 script will delete the docker volumes in chillbox instance '$CHILLBOX_INSTANCE' and workspace '$WORKSPACE' that chillbox uses for the Terraform deployments."
printf '\n%s\n' "WARNING:
Removing the Terraform tfstate volume should only be done if the deployed
environment has already been destroyed or the terraform state files have already
been pulled. The pull-terraform-tfstate.sh script can be used to accomplish this.
"
volume_list="$(docker volume list \
  --filter "name=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE}" \
  --filter "name=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE}" \
  --filter "name=chillbox-terraform-dev-dotgnupg--$CHILLBOX_INSTANCE-${WORKSPACE}" \
  --filter "name=chillbox-terraform-dev-terraformdotd--$CHILLBOX_INSTANCE-${WORKSPACE}" \
  --filter "name=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE}" \
  --quiet)"
  test -n "$volume_list" || (printf '\n%s\n' "No docker volumes found to delete in chillbox instance '$CHILLBOX_INSTANCE' and workspace '$WORKSPACE'." && exit 1)
printf '\n%s\n' "$volume_list"
printf '\n%s\n' "Continue? [y/n]"
read -r confirm
test "$confirm" = "y" || (printf "Exiting.\n" && exit 1)

printf "\nStopping containers if they are running."

docker stop "${INFRA_CONTAINER}" 2> /dev/null || printf ""
docker rm "${INFRA_CONTAINER}" 2> /dev/null || printf ""
docker stop "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""
docker rm "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""

printf '\n%s\n\n' "Deleting the volumes for the chillbox instance '$CHILLBOX_INSTANCE' and workspace '$WORKSPACE'."
printf '%s' "$volume_list" | xargs docker volume rm
