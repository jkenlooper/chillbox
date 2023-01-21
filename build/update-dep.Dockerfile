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

COPY ./bin/install-chillbox-packages.sh /etc/chillbox/bin/install-chillbox-packages.sh

RUN <<SERVICE_DEPENDENCIES
set -o errexit

apk update
/etc/chillbox/bin/install-chillbox-packages.sh
SERVICE_DEPENDENCIES

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

COPY --chown=dev:dev ./pip-requirements.txt /home/dev/app/pip-requirements.txt
COPY --chown=dev:dev ./dep /home/dev/app/dep
RUN <<PIP_INSTALL
# Install pip and wheel
set -o errexit
python -m pip download --disable-pip-version-check \
  --exists-action i \
  --destination-directory ./dep \
  -r /home/dev/app/pip-requirements.txt
python -m pip install \
  --no-index --find-links /home/dev/app/dep \
  -r /home/dev/app/pip-requirements.txt
PIP_INSTALL

# The pip-tools and pip-audit are not needed on the chillbox server, they only
# need to be part of this container.

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

RUN <<SETUP
set -o errexit
cat <<'HERE' > /home/dev/sleep.sh
#!/usr/bin/env sh
while true; do
  printf 'z'
  sleep 60
done
HERE
chmod +x /home/dev/sleep.sh

#chown -R dev:dev /home/dev/app
SETUP

COPY --chown=dev:dev ./requirements.txt /home/dev/app/requirements.txt
RUN <<PIP_DOWNLOAD_REQ
# Download python packages described in requirements.txt
set -o errexit

su dev -c 'mkdir -p /home/dev/app/dep'
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
su dev -c 'python -m pip download --disable-pip-version-check \
    --exists-action i \
    --destination-directory "./dep" \
    -r ./requirements.txt'
PIP_DOWNLOAD_REQ

USER dev

RUN <<UPDATE_REQUIREMENTS
# Generate hashed requirements.txt that will be copied out of container.
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app/dep
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="." \
    --output-file ./requirements.txt \
    ../requirements.txt
UPDATE_REQUIREMENTS

RUN <<AUDIT
# Audit packages for known vulnerabilities
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service pypi \
    -r ./dep/requirements.txt
pip-audit \
    --local \
    --strict \
    --vulnerability-service osv \
    -r ./dep/requirements.txt
AUDIT

CMD ["/home/dev/sleep.sh"]
