# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app
RUN <<INSTALL
# Install dependencies
set -o errexit
apk update
apk add --no-cache \
  -q --no-progress \
  gcc \
  python3 \
  python3-dev \
  py3-pip \
  git \
  libffi-dev \
  build-base \
  musl-dev \
  jq \
  vim \
  mandoc man-pages docs \
  coreutils \
  openssl \
  openssh \
  sshpass \
  gnupg \
  gnupg-dirmngr

INSTALL

ENV GPG_KEY_NAME="chillbox_local"

RUN <<SETUP
set -o errexit

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

# Make it easier to ssh to the chillbox servers by using the generated
# ssh_config from terraform-020-chillbox container.
mv /etc/ssh/ssh_config /etc/ssh/ssh_config.bak
ln -s /var/lib/terraform-020-chillbox/ansible_ssh_config /etc/ssh/ssh_config
SETUP

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /home/dev/app
chown -R dev:dev /home/dev/app
su dev -c '/usr/bin/python3 -m venv /home/dev/app/.venv'
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# UPKEEP due: "2023-03-23" label: "pip-tools" interval: "+3 months"
# https://pypi.org/project/pip-tools/
ARG PIP_TOOLS_VERSION=6.12.1
RUN <<PIP_TOOLS_INSTALL
# Install pip-tools
set -o errexit
su dev -c "python -m pip install 'pip-tools==$PIP_TOOLS_VERSION'"
PIP_TOOLS_INSTALL

# UPKEEP due: "2023-03-23" label: "Python auditing tool pip-audit" interval: "+3 months"
# https://pypi.org/project/pip-audit/
ARG PIP_AUDIT_VERSION=2.4.10
RUN <<INSTALL_PIP_AUDIT
# Install pip-audit
set -o errexit
su dev -c "python -m pip install 'pip-audit==$PIP_AUDIT_VERSION'"
INSTALL_PIP_AUDIT

COPY --chown=dev:dev requirements.txt ./

RUN <<PIP_DOWNLOAD_REQ
# Download python packages that are in requirements.txt
set -o errexit
su dev -c 'mkdir -p /home/dev/app/dep'
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
su dev -c 'python -m pip download --disable-pip-version-check \
    --exists-action i \
    --destination-directory "./dep" \
    -r requirements.txt'
PIP_DOWNLOAD_REQ


USER dev

RUN <<UPDATE_REQUIREMENTS
# Generate the hashed requirements.txt file.
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="./dep" \
    --output-file ./requirements-hashed.txt \
    requirements.txt
UPDATE_REQUIREMENTS

RUN <<AUDIT
# Audit packages for known vulnerabilities
set -o errexit
# Change directory so the find-links can be relative.
cd /home/dev/app
set -- ""

# UPKEEP due: "2023-04-21" label: "Vuln exception PYSEC-2020-221" interval: "+3 months"
# Not using aws_ssm.
# https://osv.dev/vulnerability/PYSEC-2020-221
set -- "$@" --ignore-vuln "PYSEC-2020-221"

# UPKEEP due: "2023-04-21" label: "Vuln exception PYSEC-2020-220" interval: "+3 months"
# Not using aws_ssm.
# https://osv.dev/vulnerability/PYSEC-2020-220
set -- "$@" --ignore-vuln "PYSEC-2020-220"

# UPKEEP due: "2023-04-21" label: "Vuln exception PYSEC-2021-125" interval: "+3 months"
# Not applicable for current use case.
# https://osv.dev/vulnerability/PYSEC-2021-125
set -- "$@" --ignore-vuln "PYSEC-2021-125"

pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service pypi \
    $@ \
    -r ./requirements-hashed.txt
pip-audit \
    --local \
    --strict \
    --vulnerability-service osv \
    $@ \
    -r ./requirements-hashed.txt
AUDIT

RUN <<PIP_INSTALL_REQ
# Install dependencies listed in hashed requirements.txt.
set -o errexit

pip install --disable-pip-version-check --compile \
    --no-index \
    --find-links=./dep \
    -r ./requirements-hashed.txt

# Confirm that ansible has been installed
which ansible
ansible --version
ansible-community --version

# Confirm that ansible-lint has been installed
which ansible-lint
ansible-lint --version
PIP_INSTALL_REQ

WORKDIR /usr/local/src/chillbox-ansible
# https://docs.ansible.com/ansible/latest/installation_guide/intro_configuration.html
COPY --chown=dev:dev ansible.cfg /etc/ansible/ansible.cfg
COPY README.md README.md
COPY .config .config
COPY bin bin

ENV PATH=/usr/local/src/chillbox-ansible/bin:${PATH}

COPY roles roles
COPY playbooks playbooks

# Set CHILLBOX_INSTANCE and WORKSPACE when running the container.
ENV CHILLBOX_INSTANCE=""
ENV WORKSPACE=""

#CMD ["/usr/local/src/chillbox-ansible/bin/doit.sh", "-s", "playbook", "--", "playbooks/bootstrap-chillbox-init-credentials.playbook.yml"]
