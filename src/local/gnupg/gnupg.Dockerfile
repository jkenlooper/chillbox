# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

RUN <<INSTALL
set -o errexit
apk update
apk add \
  jq \
  vim \
  mandoc man-pages docs \
  coreutils \
  openssh-keygen \
  gnupg \
  gnupg-dirmngr

INSTALL

WORKDIR /usr/local/src/chillbox-gnupg

ENV PATH=/usr/local/src/chillbox-gnupg/bin:${PATH}
ENV GPG_KEY_NAME="chillbox_local"

RUN <<SETUP
set -o errexit

addgroup dev
adduser -G dev -D dev
chown -R dev:dev .

mkdir -p /home/dev/.gnupg
chown -R dev:dev /home/dev/.gnupg
chmod -R 0700 /home/dev/.gnupg

mkdir -p /var/lib/chillbox-gnupg
chown -R dev:dev /var/lib/chillbox-gnupg
chmod -R 0700 /var/lib/chillbox-gnupg

SETUP

COPY --chown=dev:dev bin bin

CMD ["/usr/local/src/chillbox-gnupg/bin/init.sh"]
