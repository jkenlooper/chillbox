# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2022-12-14" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.2.7
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.2.7@sha256:8e4d010fc675dbae1eb6eee07b8fb4895b04d144152d2ef5ad39724857857ccb

RUN <<INSTALL
set -o errexit
apk update
apk add \
  jq \
  vim \
  mandoc man-pages docs \
  coreutils \
  openssl \
  openssh-keygen \
  gnupg \
  gnupg-dirmngr

# Only needs python when using certbot tool to register the account.
apk add \
  python3 \
  py3-pip
ln -s -f /usr/bin/python3 /usr/bin/python

INSTALL

WORKDIR /usr/local/src/chillbox-terraform

ENV GPG_KEY_NAME="chillbox_local"
ENV TF_VAR_GPG_KEY_NAME="$GPG_KEY_NAME"
ENV DECRYPTED_TFSTATE="/run/tmp/secrets/doterra/terraform.tfstate.json"
ENV ENCRYPTED_TFSTATE="/var/lib/terraform-010-infra/terraform.tfstate.json.asc"

RUN <<SETUP
set -o errexit
# TODO Set the specific id to use for dev user
#addgroup -g 44444 dev
#adduser -u 44444 -G dev -s /bin/sh -D dev
addgroup dev
adduser -G dev -D dev
chown -R dev:dev .

mkdir -p /home/dev/.gnupg
chown -R dev:dev /home/dev/.gnupg
chmod -R 0700 /home/dev/.gnupg

mkdir -p /var/lib/doterra
chown -R dev:dev /var/lib/doterra
chmod -R 0700 /var/lib/doterra

mkdir -p /var/lib/terraform-010-infra
chown -R dev:dev /var/lib/terraform-010-infra
chmod -R 0700 /var/lib/terraform-010-infra
SETUP

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /usr/local/src/chillbox-terraform
/usr/bin/python3 -m venv /usr/local/src/chillbox-terraform/.venv
# The dev user will need write access since pip install will be adding files to
# the .venv directory.
chown -R dev:dev /usr/local/src/chillbox-terraform/.venv
PYTHON_VIRTUALENV

# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/usr/local/src/chillbox-terraform/.venv
ENV PATH=/usr/local/src/chillbox-terraform/bin:$VIRTUAL_ENV/bin:${PATH}

ARG SITES_ARTIFACT
ENV SITES_ARTIFACT="$SITES_ARTIFACT"

COPY --chown=dev:dev 010-infra/variables.tf ./
COPY --chown=dev:dev 010-infra/main.tf ./
COPY --chown=dev:dev 010-infra/outputs.tf ./
COPY --chown=dev:dev 010-infra/bootstrap-chillbox-init-credentials.sh.tftpl .
COPY --chown=dev:dev 010-infra/.terraform.lock.hcl ./
RUN <<TERRAFORM_INIT
set -o errexit
# Creates the /home/dev/.terraform.d directory.
# Use 'terraform init -upgrade' since the tf files may have been updated with
# a newer provider version.
su dev -c "terraform init -upgrade"

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

COPY --chown=dev:dev bin bin
COPY --chown=dev:dev 010-infra/bin/ bin/
