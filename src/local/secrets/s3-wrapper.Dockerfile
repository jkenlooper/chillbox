# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-07-12" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.15.4
# docker image ls --digests alpine
FROM alpine:3.15.4@sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454

WORKDIR /usr/local/src/s3-wrapper

RUN <<INSTALL
apk update
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  unzip \
  gnupg \
  gnupg-dirmngr

install_aws_cli_dir="$(mktemp -d)"

# UPKEEP due: "2022-07-12" label: "install-aws-cli gist" interval: "+3 months"
# https://gist.github.com/jkenlooper/78dcbea2cfe74231a7971d8d66fa4bd0
# Based on https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
wget https://gist.github.com/jkenlooper/78dcbea2cfe74231a7971d8d66fa4bd0/archive/23066345e862578c1cbca7ae6c65e983a0aff3a6.zip \
  -O "$install_aws_cli_dir/install-aws-cli.zip"
echo "dbba9d0904ef5f57fba8dc4a38ce7b53  $install_aws_cli_dir/install-aws-cli.zip" | md5sum -c

unzip -j "$install_aws_cli_dir/install-aws-cli.zip" -d "$install_aws_cli_dir"
chmod +x "$install_aws_cli_dir/install-aws-cli.sh"
"$install_aws_cli_dir/install-aws-cli.sh"

INSTALL

RUN <<DEPENDENCIES
apk update
apk add sed attr grep coreutils jq gnupg gnupg-dirmngr

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim
DEPENDENCIES

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

COPY --chown=dev:dev _dev_tty.sh bin/
COPY --chown=dev:dev _decrypt_file_as_dev_user.sh bin/
