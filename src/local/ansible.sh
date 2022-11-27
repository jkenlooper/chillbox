#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
ansible_dir="$project_dir/src/ansible"

# This script shouldn't be run directly. Do a sanity check still.
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $script_name: CHILLBOX_INSTANCE variable is empty" && exit 1)
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)

INFRA_CONTAINER="chillbox-terraform-010-infra-$CHILLBOX_INSTANCE-$WORKSPACE"
TERRAFORM_CHILLBOX_CONTAINER="chillbox-terraform-020-chillbox-$CHILLBOX_INSTANCE-$WORKSPACE"

export ANSIBLE_IMAGE="chillbox-ansible:latest"
export ANSIBLE_CONTAINER="chillbox-ansible-$CHILLBOX_INSTANCE-$WORKSPACE"

"$project_dir/src/local/_docker_build_ansible.sh"

# The private key file is set in the ansible config so ssh-agent doesn't have to
# be used. The private ssh key should not be generated with a passphrase when
# doing it this way.
# private_key_file=/run/tmp/ansible/ssh/ansible.pem
#
# ssh key setup
# https://docs.ansible.com/ansible/latest/user_guide/connection_details.html

run_args="$@"

# Sleeper image needs no context.
sleeper_image="chillbox-sleeper"
docker image rm "$sleeper_image" || printf ""
export DOCKER_BUILDKIT=1
< "$project_dir/src/local/secrets/sleeper.Dockerfile" \
  docker build \
    -t "$sleeper_image" \
    -

tmp_ansible_etc_hosts_snippet="$(mktemp)"
docker run \
  -d \
  --name "$ANSIBLE_CONTAINER-sleeper" \
  --mount "type=volume,src=chillbox-$TERRAFORM_CHILLBOX_CONTAINER-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/terraform-020-chillbox,readonly=true" \
  "$sleeper_image" || (
    exitcode="$?"
    echo "docker exited with $exitcode exitcode. Ignoring"
  )
docker cp "$ANSIBLE_CONTAINER-sleeper:/var/lib/terraform-020-chillbox/ansible-etc-hosts-snippet" "$tmp_ansible_etc_hosts_snippet" || echo "Ignore docker cp error."
docker stop --time 0 "$ANSIBLE_CONTAINER-sleeper" || printf ""
docker rm "$ANSIBLE_CONTAINER-sleeper" || printf ""
set -- $(cat "$tmp_ansible_etc_hosts_snippet")
rm -f "$tmp_ansible_etc_hosts_snippet"

docker run \
  -i --tty \
  --rm \
  --name "$ANSIBLE_CONTAINER" \
  --env CHILLBOX_INSTANCE \
  --env WORKSPACE \
  --mount "type=tmpfs,dst=/run/tmp/secrets,tmpfs-mode=0700" \
  --mount "type=tmpfs,dst=/run/tmp/ansible,tmpfs-mode=0700" \
  --mount "type=volume,src=chillbox-dev-dotgnupg--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/home/dev/.gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-gnupg-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/chillbox-gnupg,readonly=false" \
  --mount "type=volume,src=chillbox-ansible-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/ansible,readonly=false" \
  --mount "type=volume,src=chillbox-terraform-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/doterra,readonly=true" \
  --mount "type=volume,src=chillbox-$INFRA_CONTAINER-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/terraform-010-infra,readonly=true" \
  --mount "type=volume,src=chillbox-$TERRAFORM_CHILLBOX_CONTAINER-var-lib--$CHILLBOX_INSTANCE-$WORKSPACE,dst=/var/lib/terraform-020-chillbox,readonly=true" \
  --mount "type=bind,src=$ansible_dir/bin,dst=/usr/local/src/chillbox-ansible/bin" \
  --mount "type=bind,src=$ansible_dir/playbooks,dst=/usr/local/src/chillbox-ansible/playbooks" \
  $@ \
  "$ANSIBLE_IMAGE" $run_args || (
  exitcode="$?"
  echo "docker exited with $exitcode exitcode. Continue? [y/n]"
  read -r docker_continue_confirm
  test "$docker_continue_confirm" = "y" || exit $exitcode
)

