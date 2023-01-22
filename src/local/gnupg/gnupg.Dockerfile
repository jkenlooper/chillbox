# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

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
