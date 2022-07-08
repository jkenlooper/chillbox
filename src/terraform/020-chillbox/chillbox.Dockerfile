# syntax=docker/dockerfile:1.4.1

# UPKEEP due: "2022-08-12" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.2.0-alpha-20220328
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.2.0-alpha-20220328@sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

WORKDIR /usr/local/src/chillbox-terraform

#COPY bin/install-aws-cli.sh bin/
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

RUN <<WGET_ALPINE_CUSTOM_IMAGE
# UPKEEP due: "2022-10-08" label: "Alpine Linux custom image" interval: "+3 months"
# Create this file by following instructions at jkenlooper/alpine-droplet
alpine_custom_image="https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-07-08-2149/alpine-virt-image-2022-07-08-2149.qcow2.bz2"
echo "INFO: Using alpine custom image $alpine_custom_image"
alpine_custom_image_checksum="29b8eb6b1347be0b5dfe132c2a2fcc96"
echo "INFO: Using alpine custom image checksum ${alpine_custom_image_checksum}"

set -o errexit
wget "$alpine_custom_image"
alpine_custom_image_file="$(basename "${alpine_custom_image}")"
md5sum "${alpine_custom_image_file}"
echo "${alpine_custom_image_checksum}  ${alpine_custom_image_file}" | md5sum -c
cat <<HERE > alpine_custom_image.auto.tfvars
alpine_custom_image = "${alpine_custom_image_file}"
HERE
WGET_ALPINE_CUSTOM_IMAGE

ENV GPG_KEY_NAME="chillbox_doterra"
ENV DECRYPTED_TFSTATE="/run/tmp/secrets/doterra/terraform.tfstate.json"
ENV ENCRYPTED_TFSTATE="/var/lib/terraform-020-chillbox/terraform.tfstate.json.asc"
ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}
ENV SKIP_UPLOAD="n"

#ENV endpoint_url="http://localhost:9000"

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

mkdir -p /var/lib/terraform-020-chillbox
chown -R dev:dev /var/lib/terraform-020-chillbox
chmod -R 0700 /var/lib/terraform-020-chillbox
SETUP

ARG SITES_ARTIFACT
ENV SITES_ARTIFACT="$SITES_ARTIFACT"

COPY --chown=dev:dev 020-chillbox/chillbox.tf .
COPY --chown=dev:dev 020-chillbox/variables.tf .
COPY --chown=dev:dev 020-chillbox/main.tf .
COPY --chown=dev:dev 020-chillbox/outputs.tf .
COPY --chown=dev:dev 020-chillbox/user_data_chillbox.sh.tftpl .
COPY --chown=dev:dev 020-chillbox/.terraform.lock.hcl .

RUN <<TERRAFORM_INIT
su dev -c "terraform init"

# A Terraform workspace is required so that there is a directory created for the
# terraform state location instead of a file.  This way a docker volume can be
# made for this path since volumes can only be made from paths that are
# directories.
# Creates a directory at /usr/local/src/chillbox-terraform/terraform.tfstate.d
# to store the terraform.tfstate file.
su dev -c "terraform workspace new chillbox"

TERRAFORM_INIT

ARG CHILLBOX_ARTIFACT
ENV CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT"
ARG SITES_MANIFEST
ENV SITES_MANIFEST="$SITES_MANIFEST"

COPY --chown=dev:dev 020-chillbox/upload-artifacts.sh .
COPY --chown=dev:dev bin bin
COPY --chown=dev:dev 020-chillbox/bin/ bin/
