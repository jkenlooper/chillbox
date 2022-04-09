# syntax=docker/dockerfile:1.3.0-labs

# docker pull hashicorp/terraform:1.2.0-alpha-20220328
# sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

FROM hashicorp/terraform:1.2.0-alpha-20220328@sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

RUN <<INSTALL
apk update
apk add \
  gpg \
  gpg-agent

INSTALL

COPY bin/doterra-init.sh /usr/local/bin/doterra-init.sh
COPY bin/doterra-encrypt_tfvars.sh /usr/local/bin/doterra-encrypt_tfvars.sh
COPY bin/doterra.sh /usr/local/bin/doterra.sh

WORKDIR /usr/local/src/chillbox-terraform

COPY . .

ARG WORKSPACE=development
ENV WORKSPACE=${WORKSPACE}

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

# Creates the /home/dev/.terraform.d directory.
su dev -c "terraform init"
su dev -c "terraform workspace new $WORKSPACE"
SETUP

VOLUME /home/dev/.gnupg
VOLUME /var/lib/doterra
VOLUME /usr/local/src/chillbox-terraform/.terraform
VOLUME /usr/local/src/chillbox-terraform/terraform.tfstate.d

USER dev
