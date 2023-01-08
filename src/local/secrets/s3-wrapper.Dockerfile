# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

WORKDIR /usr/local/src/s3-wrapper

RUN <<INSTALL
set -o errexit
apk update
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  unzip \
  gnupg \
  gnupg-dirmngr

# UPKEEP due: "2023-01-01" label: "s5cmd for s3 object storage" interval: "+3 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
tar x -o -f "$s5cmd_tmp_dir/$s5cmd_tar" -C "/usr/local/bin" s5cmd
rm -rf "$s5cmd_tmp_dir"

INSTALL

RUN <<DEPENDENCIES
set -o errexit
apk update
apk add sed attr grep coreutils jq gnupg gnupg-dirmngr

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim
DEPENDENCIES

RUN <<SETUP
set -o errexit
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

COPY --chown=dev:dev _dev_tty.sh bin/
COPY --chown=dev:dev _decrypt_file_as_dev_user.sh bin/
