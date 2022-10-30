# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad as build

WORKDIR /usr/local/src/ansible
RUN <<INSTALL
set -o errexit
apk update
apk add --no-cache \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  openssl \
  openssh \
  sshpass \
  gnupg \
  gnupg-dirmngr

ln -s /usr/bin/python3 /usr/bin/python
python -m venv .
/usr/local/src/ansible/bin/pip install --upgrade pip wheel

# UPKEEP due: "2022-12-17" label: "Ansible" interval: "+2 months"
# https://pypi.org/project/ansible/
/usr/local/src/ansible/bin/pip install --disable-pip-version-check ansible==6.5.0
export PATH=/usr/local/src/ansible/bin:$PATH

# Confirm that ansible has been installed
which ansible
ansible --version
ansible-community --version

# UPKEEP due: "2022-12-17" label: "Ansible Lint" interval: "+2 months"
# https://pypi.org/project/ansible-lint/
# ansible-lint uses the same ansible-core version that ansible package installs.
/usr/local/src/ansible/bin/pip install --disable-pip-version-check ansible-lint==6.8.2
export PATH=/usr/local/src/ansible/bin:$PATH

# Confirm that ansible-lint has been installed
which ansible-lint
ansible-lint --version

INSTALL

ENV PATH=/usr/local/src/ansible/bin:${PATH}

ENV GPG_KEY_NAME="chillbox_local"

RUN <<SETUP
set -o errexit
addgroup dev
adduser -G dev -D dev

mkdir -p /home/dev/.gnupg
chown -R dev:dev /home/dev/.gnupg
chmod -R 0700 /home/dev/.gnupg

mkdir -p /var/lib/doterra
chown -R dev:dev /var/lib/doterra
chmod -R 0700 /var/lib/doterra

mkdir -p /var/lib/terraform-010-infra
chown -R dev:dev /var/lib/terraform-010-infra
chmod -R 0700 /var/lib/terraform-010-infra

mkdir -p /var/lib/ansible
chown -R dev:dev /var/lib/ansible
chmod -R 0700 /var/lib/ansible

mkdir -p /etc/ansible
chown -R dev:dev /etc/ansible
chmod -R 0700 /etc/ansible
SETUP


WORKDIR /usr/local/src/chillbox-ansible
# https://docs.ansible.com/ansible/latest/installation_guide/intro_configuration.html
COPY --chown=dev:dev ansible.cfg /etc/ansible/ansible.cfg
COPY README.md README.md
COPY .config .config
COPY bin bin

ENV PATH=/usr/local/src/chillbox-ansible/bin:${PATH}

COPY playbooks playbooks

# Set CHILLBOX_INSTANCE and WORKSPACE when running the container.
ENV CHILLBOX_INSTANCE=""
ENV WORKSPACE=""
