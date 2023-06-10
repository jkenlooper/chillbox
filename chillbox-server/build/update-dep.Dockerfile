# syntax=docker/dockerfile:1.5.2

# UPKEEP due: "2023-09-03" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.18.0
# docker image ls --digests alpine
FROM alpine:3.18.0@sha256:02bb6f428431fbc2809c5d1b41eab5a68350194fb508869a33cb1af4444c9b11

RUN <<DEV_USER
# Create dev user
set -o errexit
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app

ARG EXPECTED_PYTHON_VERSION="Python 3.11.4"
COPY ./bin/install-chillbox-packages.sh /etc/chillbox/bin/install-chillbox-packages.sh

RUN <<SERVICE_DEPENDENCIES
set -o errexit

apk update
/etc/chillbox/bin/install-chillbox-packages.sh

actual_python_version="$(python -V)"
set -x; test "$actual_python_version" = "$EXPECTED_PYTHON_VERSION"; set +x
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

# The pip-tools and pip-audit are not needed on the chillbox server, they only
# need to be part of this container.
COPY --chown=dev:dev ./pip-requirements.txt /home/dev/app/pip-requirements.txt
COPY --chown=dev:dev ./pip-tools-requirements.txt /home/dev/app/pip-tools-requirements.txt

USER dev

RUN <<PIP_TOOLS_DOWNLOAD
# Download Python packages for pip-requirements.txt pip-tools-requirements.txt
set -o errexit
actual_python_version="$(python -V)"
set -x; test "$actual_python_version" = "$EXPECTED_PYTHON_VERSION"; set +x
mkdir -p /home/dev/app/pip-dep
mkdir -p /home/dev/app/pip-tools-dep
# Install these first so packages like PyYAML don't have errors with 'bdist_wheel'
python -m pip install wheel
python -m pip install pip
python -m pip install hatchling
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/pip-dep/ \
    --destination-directory /home/dev/app/pip-dep \
    -r /home/dev/app/pip-requirements.txt
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/pip-dep/ \
    --find-links /home/dev/app/pip-tools-dep/ \
    --destination-directory /home/dev/app/pip-tools-dep \
    -r /home/dev/app/pip-tools-requirements.txt
PIP_TOOLS_DOWNLOAD

RUN <<PIP_TOOLS_INSTALL
# Install pip-requirements.txt pip-tools-requirements.txt
set -o errexit
python -m pip install \
  --no-index \
  --no-build-isolation \
  --find-links /home/dev/app/pip-dep \
  -r /home/dev/app/pip-requirements.txt
python -m pip install \
  --no-index \
  --no-build-isolation \
  --find-links /home/dev/app/pip-dep \
  --find-links /home/dev/app/pip-tools-dep \
  -r /home/dev/app/pip-tools-requirements.txt
PIP_TOOLS_INSTALL

COPY --chown=dev:dev ./requirements.txt /home/dev/app/requirements.txt
COPY --chown=dev:dev ./dep /home/dev/app/dep
RUN <<PIP_DOWNLOAD_REQ
# Download python packages described in requirements.txt
set -o errexit

mkdir -p /home/dev/app/dep
cp pip-dep/* /home/dev/app/dep/
# Change to the app directory so the find-links can be relative.
cd /home/dev/app

# Support Python services managed by Gunicorn
# UPKEEP due: "2024-03-11" label: "Python gunicorn and gevent" interval: "+1 years"
# https://pypi.org/project/gunicorn/
gunicorn_version="20.1.0"
# Only download to a directory to allow the pip install to happen later with
# a set --find-links option.
python -m pip download \
  --disable-pip-version-check \
  --exists-action i \
  --no-build-isolation \
  --destination-directory /home/dev/app/dep \
  'gunicorn[gevent,setproctitle]'=="$gunicorn_version"

python -m pip download --disable-pip-version-check \
    --exists-action i \
    --find-links /home/dev/app/dep/ \
    --destination-directory /home/dev/app/dep \
    -r /home/dev/app/requirements.txt
PIP_DOWNLOAD_REQ

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

RUN <<UPDATE_REQUIREMENTS
# Generate hashed requirements.txt that will be copied out of container.
set -o errexit
# Change to the app/dep directory so the find-links can be relative.
cd /home/dev/app/dep
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="." \
    --output-file ./requirements.txt \
    ../requirements.txt
UPDATE_REQUIREMENTS

# Invalidate this layer each day so the pip-audit results are fresh.
COPY --chown=dev:dev ./.pip-audit-last-run.txt /home/dev/app/.pip-audit-last-run.txt
COPY --chown=dev:dev ./build/update-dep-run-audit.sh /home/dev/app/
RUN <<AUDIT
# Audit packages for known vulnerabilities
set -o errexit
./update-dep-run-audit.sh > /home/dev/vulnerabilities-pip-audit.txt || echo "WARNING: Vulnerabilities found."
AUDIT

CMD ["/home/dev/sleep.sh"]
