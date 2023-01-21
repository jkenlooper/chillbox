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
RUN <<DEPENDENCIES
# Install dependencies
set -o errexit
apk update
apk add --no-cache \
  -q --no-progress \
  sed attr grep coreutils jq

apk add --no-cache \
  -q --no-progress \
  build-base \
  py3-pip \
  python3 python3-dev

# Add other tools that are helpful when troubleshooting.
apk add --no-cache \
  -q --no-progress \
  mandoc man-pages docs
apk add --no-cache \
  -q --no-progress \
  vim

DEPENDENCIES

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

# UPKEEP due: "2023-03-23" label: "Python pip" interval: "+3 months"
# https://pypi.org/project/pip/
ARG PIP_VERSION=22.3.1
# UPKEEP due: "2023-03-23" label: "Python wheel" interval: "+3 months"
# https://pypi.org/project/wheel/
ARG WHEEL_VERSION=0.38.4
RUN <<PIP_INSTALL
# Install pip and wheel
set -o errexit
su dev -c "python -m pip install 'pip==$PIP_VERSION' 'wheel==$WHEEL_VERSION'"
PIP_INSTALL

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
# Audit packages for known vulnerabilities
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
# Generate the hashed requirements.txt file that the main container will use.
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
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service pypi \
    -r ./requirements-hashed.txt
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service osv \
    -r ./requirements-hashed.txt
AUDIT

RUN <<PIP_INSTALL_REQ
# Install dependencies listed in hashed requirements.txt.
set -o errexit

pip install --disable-pip-version-check --compile \
    --no-index \
    --find-links=./dep \
    -r ./requirements-hashed.txt
PIP_INSTALL_REQ

COPY --chown=dev:dev site.schema.json ./
COPY --chown=dev:dev check-json.py ./
COPY --chown=dev:dev verify-sites-artifact.sh ./

ENV SITES_ARTIFACT=""
ENV SITES_MANIFEST=""

CMD ["/home/dev/app/verify-sites-artifact.sh"]
