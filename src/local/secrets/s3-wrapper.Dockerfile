# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

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

# UPKEEP due: "2023-07-22" label: "s5cmd for s3 object storage" interval: "+6 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_checksum="379d054f434bd1fbd44c0ae43a3f0f11a25e5c23fd9d7184ceeae1065e74e94ad6fa9e42dadd32d72860b919455e22cd2100b6315fd610d8bb4cfe81474621b4"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
sha512sum "$s5cmd_tmp_dir/$s5cmd_tar"
echo "$s5cmd_checksum  $s5cmd_tmp_dir/$s5cmd_tar" | sha512sum -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_tmp_dir/$s5cmd_tar.INVALID" \
    && exit 1 \
    )
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
