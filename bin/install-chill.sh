#!/usr/bin/env sh

set -o errexit

PIP_CHILL=${PIP_CHILL:-$1}

test -n "${PIP_CHILL}" || (echo "ERROR $0: PIP_CHILL variable is empty" && exit 1)

echo "INFO $0: Installing chill version $PIP_CHILL"

apk add \
  py3-pip \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  make \
  git \
  sqlite
ln -s /usr/bin/python3 /usr/bin/python
python --version
pip install --upgrade pip
python -m pip install --disable-pip-version-check "$PIP_CHILL"
chill --version
