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
ARG GPG_KEY_NAME=chillbox
ENV GPG_KEY_NAME=$GPG_KEY_NAME
RUN <<SECRETS_PROMPT_SH
cat <<HERE > /usr/local/src/api-secrets/secrets-prompt.sh
#!/usr/bin/env sh

set -o errexit

mkdir -p /run/tmp/secrets/
mkdir -p /var/lib/secrets/

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

cat <<SECRETS > "/run/tmp/secrets/$SECRETS_CONFIG"
ANSWER1=$first_answer
ANSWER2=$second_answer
ANSWER5=$fifth_answer
SECRETS
cleanup() {
	shred -fu "/run/tmp/secrets/$SECRETS_CONFIG" || rm -f "/run/tmp/secrets/$SECRETS_CONFIG"
}
trap cleanup EXIT

gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "/var/lib/secrets/${SECRETS_CONFIG}.asc" \
  --comment "Example site1 api secrets for bridge crossing" \
  --comment "Environment workspace: $WORKSPACE" \
  --comment "Date: $(date)" \
  "/run/tmp/secrets/$SECRETS_CONFIG"


HERE
chmod +x /usr/local/src/api-secrets/secrets-prompt.sh

SECRETS_PROMPT_SH

CMD ["/usr/local/src/api-secrets/secrets-prompt.sh"]
