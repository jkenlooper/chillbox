# syntax=docker/dockerfile:1.4.1

# UPKEEP due: "2022-10-08" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.0
# docker image ls --digests alpine
FROM alpine:3.16.0@sha256:686d8c9dfa6f3ccfc8230bc3178d23f84eeaf7e457f36f271ab1acc53015037c

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

# UPKEEP due: "2022-10-08" label: "install-aws-cli gist" interval: "+3 months"
# https://gist.github.com/jkenlooper/78dcbea2cfe74231a7971d8d66fa4bd0
# Based on https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
install_aws_cli_dir="$(mktemp -d)"
wget https://gist.github.com/jkenlooper/78dcbea2cfe74231a7971d8d66fa4bd0/archive/0951e80d092960cf27f893aaa12d5ed754dc3bed.zip \
  -O "$install_aws_cli_dir/install-aws-cli.zip"
echo "9006755dfbc2cdaf192029a3a2f60941beecc868157ea265c593f11e608a906a5928dcad51a815c676e8f77593e5847e9b6023b47c28bc87b5ffeecd5708e9ac  $install_aws_cli_dir/install-aws-cli.zip" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$install_aws_cli_dir/install-aws-cli.zip" "$install_aws_cli_dir/install-aws-cli.zip.INVALID" \
    && exit 1 \
    )
unzip -j "$install_aws_cli_dir/install-aws-cli.zip" -d "$install_aws_cli_dir"
chmod +x "$install_aws_cli_dir/install-aws-cli.sh"
"$install_aws_cli_dir/install-aws-cli.sh"
rm -rf "$install_aws_cli_dir"

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
