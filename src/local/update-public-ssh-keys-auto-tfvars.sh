#!/usr/bin/env sh

set -o errexit

test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $0: CHILLBOX_INSTANCE variable is empty" && exit 1)

chillbox_config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
env_config="$chillbox_config_home/env"
test -n "$PUBLIC_SSH_KEY_LOCATIONS" || (echo "ERROR $0: PUBLIC_SSH_KEY_LOCATIONS variable is empty. Is it set in the $env_config file?" && exit 1)
test -n "$PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST" || (echo "ERROR $0: PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST variable is empty. Is it set in the $env_config file?" && exit 1)

chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"
ssh_keys_file="$chillbox_state_home/developer-public-ssh-keys.auto.tfvars.json"

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT


echo "INFO $0: Processing environment variable PUBLIC_SSH_KEY_LOCATIONS"
echo "$PUBLIC_SSH_KEY_LOCATIONS"
echo "INFO $0: Processing environment variable PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST"
echo "$PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST"
echo "INFO $0: Creating $ssh_keys_file"

accepted_pub_ssh_keys="$(mktemp)"
for ssh_key_location in ${PUBLIC_SSH_KEY_LOCATIONS}; do
  test -n "$ssh_key_location" || continue
  if [ "$ssh_key_location" != "${ssh_key_location#'https://'}" ]; then
    wget "$ssh_key_location" -O - \
      | while read -r pub_ssh_key; do
          echo "pub ssh key from URL $pub_ssh_key"
          fingerprint_sha256="$(echo "$pub_ssh_key" | ssh-keygen -l -E sha256 -f -)"
          echo "fing $fingerprint_sha256"

          echo "${PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST}" | while read -r accept_fingerprint; do
            if [ "$accept_fingerprint" = "$fingerprint_sha256" ]; then
              echo "${pub_ssh_key}" >> "$accepted_pub_ssh_keys"
              break
            fi
          done
        done
  else
    if [ "$ssh_key_location" = "${ssh_key_location#'/'}" ]; then
      echo "ERROR $0: The public ssh key location found is not an absolute file path: $ssh_key_location"
      exit 1
    fi
    if [ ! -e "$ssh_key_location" ]; then
      echo "ERROR $0: The public ssh key file ($ssh_key_location) does not exist."
      exit 1
    fi
    fingerprint_sha256="$(ssh-keygen -l -E sha256 -f "$ssh_key_location")"
    echo "${PUBLIC_SSH_KEY_FINGERPRINT_ACCEPT_LIST}" | while read -r accept_fingerprint; do
      if [ "$accept_fingerprint" = "$fingerprint_sha256" ]; then
        echo "" >> "$accepted_pub_ssh_keys"
        cat "$ssh_key_location" >> "$accepted_pub_ssh_keys"
        break
      fi
    done
  fi

done

jq --raw-input '{developer_public_ssh_keys: ([.] + [inputs] | map(select(. != ""))) }' "$accepted_pub_ssh_keys" > "$ssh_keys_file"
# Verify that the public ssh keys were added.
jq --exit-status '.developer_public_ssh_keys[]' "$ssh_keys_file" > /dev/null || (echo "ERROR $0: No public ssh keys set in $ssh_keys_file." && exit 1)
