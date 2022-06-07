# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-07-12" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.15.4
# docker image ls --digests alpine
FROM alpine:3.15.4@sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454

WORKDIR /usr/local/src/api-secrets
RUN <<DEPENDENCIES
apk update
apk add sed attr grep coreutils jq gnupg gnupg-dirmngr

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim
DEPENDENCIES

ARG WORKSPACE=development
ENV WORKSPACE=$WORKSPACE
ARG SECRETS_CONFIG=api-bridge.secrets.cfg
ENV SECRETS_CONFIG=$SECRETS_CONFIG
ARG CHILLBOX_GPG_PUBKEY_DIR=chillbox
ENV CHILLBOX_GPG_PUBKEY_DIR=$CHILLBOX_GPG_PUBKEY_DIR
ARG SLUGNAME=slugname
ENV SLUGNAME=$SLUGNAME
ARG VERSION=version
ENV VERSION=$VERSION
ARG SERVICE_HANDLER=service_handler
ENV SERVICE_HANDLER=$SERVICE_HANDLER
ARG TMPFS_DIR=/run/tmp/SLUGNAME-VERSION-SERVICE_HANDLER
ENV TMPFS_DIR=$TMPFS_DIR
ARG SERVICE_PERSISTENT_DIR=/var/lib/SLUGNAME-SERVICE_HANDLER/WORKSPACE
ENV SERVICE_PERSISTENT_DIR=$SERVICE_PERSISTENT_DIR

RUN <<SECRETS_PROMPT_SH
cat <<HERE > /usr/local/src/api-secrets/secrets-prompt.sh
#!/usr/bin/env sh

set -o errexit
set -o nounset

mkdir -p "$TMPFS_DIR/secrets/"
mkdir -p "$SERVICE_PERSISTENT_DIR"

gpg --import /var/lib/chillbox/chillbox.gpg

echo "Stop. Who would cross the Bridge of Death must answer me these questions three, ere the other side he see."

printf "What…"
sleep 1
printf " is your name?"
read first_answer

printf "What…"
sleep 1
printf " is your quest?"
read second_answer

printf "What…"
sleep 1
printf " is your favourite colour?"
read fifth_answer

echo "Go on. Off you go."

cat <<SECRETS > "$TMPFS_DIR/secrets/$SECRETS_CONFIG"
ANSWER1=$first_answer
ANSWER2=$second_answer
ANSWER5=$fifth_answer
SECRETS
cleanup() {
	shred -fu "$TMPFS_DIR/secrets/$SECRETS_CONFIG" || rm -f "$TMPFS_DIR/secrets/$SECRETS_CONFIG"
}
trap cleanup EXIT

# Support multiple chillbox servers which will have their own gpg pubkeys.
find "$CHILLBOX_GPG_PUBKEY_DIR" -depth -mindepth 1 -maxdepth 1 -name 'chillbox*.gpg' \
  | while read -r chillbox_gpg_key_file; do
    gpg_key_name="$(basename "$chillbox_gpg_key_file" .gpg)"
    encrypted_secrets_config_file="$SERVICE_PERSISTENT_DIR/encrypted_secrets/$gpg_key_name/${SECRETS_CONFIG}.asc"
    encrypted_secrets_config_dir="$(dirname "$encrypted_secrets_config_file")"
    mkdir -p "$encrypted_secrets_config_dir"
    rm -f "$encrypted_secrets_config_file"
    gpg --encrypt --recipient "${gpg_key_name}" --armor --output "$encrypted_secrets_config_file" \
      --comment "Example site1 api secrets for bridge crossing" \
      --comment "Environment workspace: $WORKSPACE" \
      --comment "Date: $(date)" \
      "$TMPFS_DIR/secrets/$SECRETS_CONFIG"
  done


HERE
chmod +x /usr/local/src/api-secrets/secrets-prompt.sh

SECRETS_PROMPT_SH

CMD ["/usr/local/src/api-secrets/secrets-prompt.sh"]
