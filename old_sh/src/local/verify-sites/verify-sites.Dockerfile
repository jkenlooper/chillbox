# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

RUN <<DEV_USER
# Create dev user
set -o errexit
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app

ARG EXPECTED_PYTHON_VERSION="Python 3.10.10"
RUN <<PACKAGE_DEPENDENCIES
# apk add package dependencies
set -o errexit
apk update
apk add --no-cache \
  -q --no-progress \
  gcc \
  python3 \
  python3-dev \
  py3-pip \
  libffi-dev \
  build-base \
  musl-dev

actual_python_version="$(python -V)"
set -x; test "$actual_python_version" = "$EXPECTED_PYTHON_VERSION"; set +x
PACKAGE_DEPENDENCIES

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /home/dev/app
chown -R dev:dev /home/dev/app
su dev -c 'python -m venv /home/dev/app/.venv'
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --chown=dev:dev src/chillbox/pip-requirements.txt ./
COPY --chown=dev:dev src/chillbox/pip-tools-requirements.txt ./
COPY --chown=dev:dev src/local/verify-sites/requirements.txt ./
COPY --chown=dev:dev src/chillbox/dep /home/dev/app/dep

USER dev

RUN <<PIP_DOWNLOAD
# Download Python packages for *requirements.txt
set -o errexit
actual_python_version="$(python -V)"
set -x; test "$actual_python_version" = "$EXPECTED_PYTHON_VERSION"; set +x
# Install these first so packages like PyYAML don't have errors with 'bdist_wheel'
python -m pip install wheel
python -m pip install pip
python -m pip install hatchling
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/dep/ \
    --destination-directory /home/dev/app/dep \
    -r /home/dev/app/pip-requirements.txt
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/dep/ \
    --destination-directory /home/dev/app/dep \
    -r /home/dev/app/pip-tools-requirements.txt
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/dep/ \
    --destination-directory /home/dev/app/dep \
    -r /home/dev/app/requirements.txt
PIP_DOWNLOAD

RUN <<PIP_INSTALL
# Install *requirements.txt
set -o errexit
python -m pip install \
  --no-index \
  --no-build-isolation \
  --find-links /home/dev/app/dep/ \
  -r /home/dev/app/pip-requirements.txt
python -m pip install \
  --no-index \
  --no-build-isolation \
  --find-links /home/dev/app/dep/ \
  -r /home/dev/app/pip-tools-requirements.txt
python -m pip install \
  --no-index \
  --no-build-isolation \
  --find-links /home/dev/app/dep/ \
  -r /home/dev/app/requirements.txt
PIP_INSTALL

RUN <<UPDATE_REQUIREMENTS
# Generate the hashed requirements.txt file that the main container will use.
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="./dep" \
    --output-file ./pip-requirements-hashed.txt \
    pip-requirements.txt
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

set -- ""

# Add any exceptions to vulnerabilities like this:
#
# exampleUPKEEP due: "2023-04-21" label: "Vuln exception GHSA-r9hx-vwmv-q579" interval: "+3 months"
# n/a
# https://osv.dev/vulnerability/GHSA-r9hx-vwmv-q579
#set -- "$@" --ignore-vuln "GHSA-r9hx-vwmv-q579"

# Change directory so the find-links can be relative.
cd /home/dev/app
for req_hashed_txt in ./pip-requirements-hashed.txt ./requirements-hashed.txt; do
  pip-audit \
      --require-hashes \
      --local \
      --strict \
      --vulnerability-service pypi \
      $@ \
      -r "$req_hashed_txt"
      -r ./dep/requirements.txt
  pip-audit \
      --local \
      --strict \
      --vulnerability-service osv \
      $@ \
      -r "$req_hashed_txt"
done
AUDIT

RUN <<PIP_INSTALL_REQ
# Install dependencies listed in hashed requirements.txt.
set -o errexit

pip install --disable-pip-version-check --compile \
    --no-index \
    --find-links=./dep \
    -r ./requirements-hashed.txt
PIP_INSTALL_REQ

COPY --chown=dev:dev src/local/verify-sites/site.schema.json ./
COPY --chown=dev:dev src/local/verify-sites/check-json.py ./
COPY --chown=dev:dev src/local/verify-sites/verify-sites-artifact.sh ./

ENV SITES_ARTIFACT=""
ENV SITES_MANIFEST=""

CMD ["/home/dev/app/verify-sites-artifact.sh"]
