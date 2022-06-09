# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-07-12" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.15.4
# docker image ls --digests alpine
FROM alpine:3.15.4@sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454

WORKDIR /usr/local/src/s3-wrapper

COPY bin/install-aws-cli.sh /usr/local/src/s3-wrapper/bin/
RUN <<INSTALL
apk update
/usr/local/src/s3-wrapper/bin/install-aws-cli.sh
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  gnupg \
  gnupg-dirmngr

INSTALL

RUN <<DEPENDENCIES
apk update
apk add sed attr grep coreutils jq gnupg gnupg-dirmngr

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim
DEPENDENCIES

# Set WORKSPACE before SETUP to invalidate that layer.
ARG WORKSPACE=development
ENV WORKSPACE=${WORKSPACE}
ENV GPG_KEY_NAME="chillbox_doterra__${WORKSPACE}"


RUN <<SETUP
addgroup dev
adduser -G dev -D dev
chown -R dev:dev .

mkdir -p /run/tmp/secrets
chown -R dev:dev /run/tmp/secrets
chmod -R 0700 /run/tmp/secrets

mkdir -p /home/dev/.gnupg
chown -R dev:dev /home/dev/.gnupg
chmod -R 0700 /home/dev/.gnupg

mkdir -p /var/lib/doterra
chown -R dev:dev /var/lib/doterra
chmod -R 0700 /var/lib/doterra

SETUP

ENV PATH=/usr/local/src/s3-wrapper/bin:${PATH}

COPY --chown=dev:dev .build-artifacts-vars .
COPY --chown=dev:dev terraform-bin/_dev_tty.sh bin/
COPY --chown=dev:dev terraform-bin/_decrypt_file_as_dev_user.sh bin/
