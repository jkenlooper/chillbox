#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

usage() {
  cat <<HERE

Decrypts and copies the user-data.sh from the terraform-010-infra container to the provided file path.

Usage:
  $script_name -h
  $script_name <options> <file>

Options:
  -h                  Show this help message.

  -i <instance_name>  Pass in the name of the chillbox instance.

  -w <workspace>      Set the workspace environment.
                      Must be: development, test, acceptance, production

Args:
  <file>        Output the user-data.sh script to this file path

HERE
}

chillbox_instance=""
workspace=""

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
output_user_data_file="$1"



export CHILLBOX_INSTANCE="$chillbox_instance"
export WORKSPACE="$workspace"
#chillbox_config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
#env_config="$chillbox_config_home/env"
export chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"


export INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"

# Sleeper image needs no context.
sleeper_image="chillbox-sleeper"
docker image rm "$sleeper_image" > /dev/null 2>&1 || printf ""
export DOCKER_BUILDKIT=1
echo "INFO $script_name: Building docker image: $sleeper_image"
< "$project_dir/src/local/secrets/sleeper.Dockerfile" \
  docker build \
    --quiet \
    -t "$sleeper_image" \
    -

tmp_container_name="$sleeper_image-$CHILLBOX_INSTANCE-$WORKSPACE"
docker run \
  -d \
  --name "$tmp_container_name" \
  --mount "type=volume,src=chillbox-${INFRA_CONTAINER}-var-lib--$CHILLBOX_INSTANCE-${WORKSPACE},dst=/var/lib/terraform-010-infra,readonly=true" \
  "$sleeper_image"
docker cp "$tmp_container_name:/var/lib/terraform-010-infra/bootstrap-chillbox-init-credentials.sh.encrypted" "$chillbox_state_home/bootstrap-chillbox-init-credentials.sh.encrypted"

# TODO The bootstrap_chillbox_pass to decrypt the bootstrap-chillbox-init-credentials.sh.encrypted is
# in the output.json.asc, but that is encrypted with the gnupg key that is on
# the docker volume.
docker cp "$tmp_container_name:/var/lib/terraform-010-infra/output.json.asc" "$chillbox_state_home/output.json.asc"

docker stop --time 0 "$tmp_container_name" > /dev/null 2>&1 || printf ""
docker rm "$tmp_container_name" > /dev/null 2>&1 || printf ""

echo "TODO $script_name: Decrypting the $chillbox_state_home/output.json.asc file is not supported at this time."
exit 1

bootstrap_chillbox_pass="$(jq -r '.bootstrap_chillbox_pass.value' "$chillbox_state_home/output.json")"

openssl enc -aes-256-cbc -d -md sha512 -pbkdf2 -a -iter 100000 -salt -pass "pass:${bootstrap_chillbox_pass}" -in "${chillbox_state_home}/bootstrap-chillbox-init-credentials.sh.encrypted" -out "$output_user_data_file"
chmod +x "$output_user_data_file"
