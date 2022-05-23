#!/usr/bin/env sh

set -o errexit

# echo is bad... mmm k

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"
terraform_infra_dir="$project_dir/terraform-010-infra"
terraform_chillbox_dir="$project_dir/terraform-020-chillbox"

infra_container="chillbox-$(basename "${terraform_infra_dir}")"
terraform_chillbox_container="chillbox-$(basename "${terraform_chillbox_dir}")"

# Allow setting defaults from an env file
ENV_CONFIG=${1:-"$project_dir/.env"}
# shellcheck source=/dev/null
test -f "${ENV_CONFIG}" && . "${ENV_CONFIG}"

WORKSPACE="${WORKSPACE:-development}"
test -n "$WORKSPACE" || (printf '\n%s\n' "ERROR $0: WORKSPACE variable is empty" && exit 1)
if [ "$WORKSPACE" != "development" ] && [ "$WORKSPACE" != "test" ] && [ "$WORKSPACE" != "acceptance" ] && [ "$WORKSPACE" != "production" ]; then
  printf '\n%s\n' "ERROR $0: WORKSPACE variable is non-valid. Should be one of development, test, acceptance, production."
  exit 1
fi


printf '\n%s\n' "The $0 script will delete the docker volumes in workspace '$WORKSPACE' that chillbox uses for the Terraform deployments."
printf '\n%s\n' "WARNING:
Removing the Terraform tfstate volume should only be done if the deployed
environment has already been destroyed or the terraform state files have already
been pulled. The pull-terraform-tfstate.sh script can be used to accomplish this.
"
volume_list="$(docker volume list \
  --filter "name=chillbox-${infra_container}-tfstate--${WORKSPACE}" \
  --filter "name=chillbox-${infra_container}-var-lib--${WORKSPACE}" \
  --filter "name=chillbox-${terraform_chillbox_container}-tfstate--${WORKSPACE}" \
  --filter "name=chillbox-${terraform_chillbox_container}-var-lib--${WORKSPACE}" \
  --filter "name=chillbox-terraform-dev-dotgnupg--${WORKSPACE}" \
  --filter "name=chillbox-terraform-dev-terraformdotd--${WORKSPACE}" \
  --filter "name=chillbox-terraform-run-tmp-secrets--${WORKSPACE}" \
  --filter "name=chillbox-terraform-var-lib--${WORKSPACE}" \
  --quiet)"
  test -n "$volume_list" || (printf '\n%s\n' "No docker volumes found to delete in workspace '$WORKSPACE'." && exit 1)
printf '\n%s\n' "$volume_list"
printf '\n%s\n' "Continue? [y/n]"
read -r confirm
test "$confirm" = "y" || (printf "Exiting.\n" && exit 1)

printf "\nStopping containers if they are running."

docker stop "${infra_container}" 2> /dev/null || printf ""
docker rm "${infra_container}" 2> /dev/null || printf ""
docker stop "${terraform_chillbox_container}" 2> /dev/null || printf ""
docker rm "${terraform_chillbox_container}" 2> /dev/null || printf ""

printf '\n%s\n\n' "Deleting the volumes for the workspace '$WORKSPACE'."
printf '%s' "$volume_list" | xargs docker volume rm
