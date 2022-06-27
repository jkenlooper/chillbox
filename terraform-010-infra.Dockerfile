# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-08-12" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.2.0-alpha-20220328
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.2.0-alpha-20220328@sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

RUN <<INSTALL
apk update
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  gnupg \
  gnupg-dirmngr

INSTALL

WORKDIR /usr/local/src/chillbox-terraform

ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}
ENV GPG_KEY_NAME="chillbox_doterra"
ENV DECRYPTED_TFSTATE="/run/tmp/secrets/doterra/terraform.tfstate.json"
ENV ENCRYPTED_TFSTATE="/var/lib/terraform-010-infra/terraform.tfstate.json.asc"

RUN <<SETUP
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

COPY --chown=dev:dev terraform-010-infra/variables.tf ./
COPY --chown=dev:dev terraform-010-infra/main.tf ./
COPY --chown=dev:dev terraform-010-infra/.terraform.lock.hcl ./
RUN <<TERRAFORM_INIT
# Creates the /home/dev/.terraform.d directory.
su dev -c "terraform init"

# A Terraform workspace is required so that there is a directory created for the
# terraform state location instead of a file.  This way a docker volume can be
# made for this path since volumes can only be made from paths that are
# directories.
# Creates a directory at /usr/local/src/chillbox-terraform/terraform.tfstate.d
# to store the terraform.tfstate file.
su dev -c "terraform workspace new chillbox"

TERRAFORM_INIT

COPY --chown=dev:dev terraform-bin bin
COPY --chown=dev:dev terraform-010-infra/bin/ bin/
