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

ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}
ENV GPG_KEY_NAME="chillbox_local"

#TODO

