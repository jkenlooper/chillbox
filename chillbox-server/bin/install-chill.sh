#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

echo "INFO $script_name: Installing chill dependencies"
apk add \
  -q --no-progress \
  build-base \
  gcc \
  libffi-dev \
  musl-dev \
  py3-pip \
  python3 \
  python3-dev \
  sqlite

# Output the python version to verify tests.
python --version
