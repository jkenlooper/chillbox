#!/usr/bin/env sh

set -o errexit

usage() {
  cat <<HERE
Remove container volumes associated with a Terraform workspace.
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

# project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

export WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (printf '\n%s\n' "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  printf '\n%s\n' "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi

env_config="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$WORKSPACE/env"
if [ -f "${env_config}" ]; then
  # shellcheck source=/dev/null
  . "${env_config}"
else
  echo "ERROR $0: No $env_config file found."
  exit 1
fi

# The WORKSPACE is passed as a build-arg for the images, so make the image and
# container name also have that in their name.
export INFRA_IMAGE="chillbox-terraform-010-infra-$WORKSPACE"
export INFRA_CONTAINER="chillbox-terraform-010-infra-$WORKSPACE"
export TERRAFORM_CHILLBOX_IMAGE="chillbox-terraform-020-chillbox-$WORKSPACE"
export TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$WORKSPACE"


printf '\n%s\n' "The $0 script will delete the docker volumes in workspace '$WORKSPACE' that chillbox uses for the Terraform deployments."
printf '\n%s\n' "WARNING:
Removing the Terraform tfstate volume should only be done if the deployed
environment has already been destroyed or the terraform state files have already
been pulled. The pull-terraform-tfstate.sh script can be used to accomplish this.
"
volume_list="$(docker volume list \
  --filter "name=chillbox-${INFRA_CONTAINER}-var-lib--${WORKSPACE}" \
  --filter "name=chillbox-${TERRAFORM_CHILLBOX_CONTAINER}-var-lib--${WORKSPACE}" \
  --filter "name=chillbox-terraform-dev-dotgnupg--${WORKSPACE}" \
  --filter "name=chillbox-terraform-dev-terraformdotd--${WORKSPACE}" \
  --filter "name=chillbox-terraform-var-lib--${WORKSPACE}" \
  --quiet)"
  test -n "$volume_list" || (printf '\n%s\n' "No docker volumes found to delete in workspace '$WORKSPACE'." && exit 1)
printf '\n%s\n' "$volume_list"
printf '\n%s\n' "Continue? [y/n]"
read -r confirm
test "$confirm" = "y" || (printf "Exiting.\n" && exit 1)

printf "\nStopping containers if they are running."

docker stop "${INFRA_CONTAINER}" 2> /dev/null || printf ""
docker rm "${INFRA_CONTAINER}" 2> /dev/null || printf ""
docker stop "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""
docker rm "${TERRAFORM_CHILLBOX_CONTAINER}" 2> /dev/null || printf ""

printf '\n%s\n\n' "Deleting the volumes for the workspace '$WORKSPACE'."
printf '%s' "$volume_list" | xargs docker volume rm
