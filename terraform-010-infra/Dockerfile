# syntax=docker/dockerfile:1.3.0-labs

# docker pull hashicorp/terraform:1.2.0-alpha-20220328
# sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

FROM hashicorp/terraform:1.2.0-alpha-20220328@sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

RUN <<INSTALL
apk update
apk add \
  jq \
  gpg \
  gpg-agent

INSTALL

WORKDIR /usr/local/src/chillbox-terraform

COPY . .

ARG WORKSPACE=development
ENV WORKSPACE=${WORKSPACE}
ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}

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

# Creates the /home/dev/.terraform.d directory.
su dev -c "terraform init"
su dev -c "terraform workspace new $WORKSPACE"
SETUP

USER dev
