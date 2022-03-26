#!/usr/bin/env sh

set -o errexit

PIP_CHILL=${PIP_CHILL:-$1}

test -n "${PIP_CHILL}" || (echo "ERROR $0: PIP_CHILL variable is empty" && exit 1)

echo "INFO $0: Installing chill version $PIP_CHILL"

apk add \
  -q --no-progress \
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

ln -s -f /usr/bin/python3 /usr/bin/python

# Output the python version to verify tests.
python --version
pip install --upgrade --quiet pip
python -m pip install --quiet --disable-pip-version-check "$PIP_CHILL"

# Output the chill version to verify tests.
echo "Chill $(chill --version)"
