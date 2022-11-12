# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

WORKDIR /usr/local/src/api-secrets
RUN <<DEPENDENCIES
set -o errexit
apk update
apk add sed attr grep coreutils jq

# Include openssl to do asymmetric encryption
apk add openssl

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim
DEPENDENCIES

ARG SECRETS_CONFIG=api-bridge.secrets.cfg
ENV SECRETS_CONFIG=$SECRETS_CONFIG
ARG CHILLBOX_PUBKEY_DIR
ENV CHILLBOX_PUBKEY_DIR=$CHILLBOX_PUBKEY_DIR
ARG SLUGNAME=slugname
ENV SLUGNAME=$SLUGNAME
ARG VERSION=version
ENV VERSION=$VERSION
ARG SERVICE_HANDLER=service_handler
ENV SERVICE_HANDLER=$SERVICE_HANDLER
ARG TMPFS_DIR=/run/tmp/SLUGNAME-VERSION-SERVICE_HANDLER
ENV TMPFS_DIR=$TMPFS_DIR
ARG SERVICE_PERSISTENT_DIR=/var/lib/SLUGNAME-SERVICE_HANDLER
ENV SERVICE_PERSISTENT_DIR=$SERVICE_PERSISTENT_DIR

# Allow changing the binary to encrypt a file since it lives in the data volume
# with the public keys. Mostly so local development can switch it to use a fake
# encryption command.
ENV ENCRYPT_FILE=encrypt-file

RUN <<SECRETS_PROMPT_SH
set -o errexit
cat <<'HERE' > /usr/local/src/api-secrets/secrets-prompt.sh
#!/usr/bin/env sh

set -o errexit
set -o nounset

test -e "$CHILLBOX_PUBKEY_DIR" || (echo "ERROR $0: No directory at $CHILLBOX_PUBKEY_DIR" && exit 1)
pubkeys_list="$(find "$CHILLBOX_PUBKEY_DIR" -depth -mindepth 1 -maxdepth 1 -name '*.public.pem')"
test -n "$pubkeys_list" || (echo "ERROR $0: No chillbox public keys found at $CHILLBOX_PUBKEY_DIR" && exit 1)
test -x "$CHILLBOX_PUBKEY_DIR/$ENCRYPT_FILE" || (echo "ERROR $0: The encrypt file doesn't exist or is not executable: $CHILLBOX_PUBKEY_DIR/$ENCRYPT_FILE" && exit 1)

mkdir -p "$TMPFS_DIR/secrets/"
mkdir -p "$SERVICE_PERSISTENT_DIR"


printf "\n\n%s\n" "Stop."

typeit() {
  for w in $1; do
    chars="$(echo "$w" | sed 's/\(.\)/\1 /g')"
    for c in $chars; do
      printf "$c"
      sleep 0.1
    done
    printf " "
    sleep 0.1
  done
}

typeit "Who would cross the Bridge of Death must answer me these questions three, ere the other side he see."
printf "\n\n"

sleep 1
printf "\nWhat… "
sleep 1
typeit "is your name?"
printf "  "
read first_answer

printf "\nWhat… "
sleep 1
typeit "is your quest?"
printf "  "
read second_answer

printf "\nWhat… "
sleep 1
typeit "is your favourite colour?"
printf "  "
read fifth_answer

printf "\n\n"
typeit "Go on. Off you go."
printf "\n\n"

cat <<SECRETS > "$TMPFS_DIR/secrets/$SECRETS_CONFIG"
ANSWER1="$first_answer"
ANSWER2="$second_answer"
ANSWER5="$fifth_answer"
SECRETS
cleanup() {
	shred -fu "$TMPFS_DIR/secrets/$SECRETS_CONFIG" || rm -f "$TMPFS_DIR/secrets/$SECRETS_CONFIG"
}
trap cleanup EXIT

# Support multiple chillbox servers which will have their own pubkeys.
find "$CHILLBOX_PUBKEY_DIR" -depth -mindepth 1 -maxdepth 1 -name '*.public.pem' \
  | while read -r chillbox_public_key_file; do
    key_name="$(basename "$chillbox_public_key_file" .public.pem)"
    encrypted_secrets_config_file="$SERVICE_PERSISTENT_DIR/encrypted-secrets/$key_name/${SECRETS_CONFIG}"
    encrypted_secrets_config_dir="$(dirname "$encrypted_secrets_config_file")"
    mkdir -p "$encrypted_secrets_config_dir"
    rm -f "$encrypted_secrets_config_file"
    "$CHILLBOX_PUBKEY_DIR/$ENCRYPT_FILE" -k "$chillbox_public_key_file" -o "$encrypted_secrets_config_file" "$TMPFS_DIR/secrets/$SECRETS_CONFIG"
  done

HERE
chmod +x /usr/local/src/api-secrets/secrets-prompt.sh

SECRETS_PROMPT_SH

ENTRYPOINT ["/usr/local/src/api-secrets/secrets-prompt.sh"]
