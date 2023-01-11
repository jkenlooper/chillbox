#!/usr/bin/env sh

set -o errexit

# Prevent reinstalling chill by checking the version.
current_chill_version="$(command -v chill > /dev/null 2>&1 && chill --version || printf "")"
if [ -n "$current_chill_version" ]; then
  echo "INFO $0: Skipping reinstall of chill version $current_chill_version"
  # Output the python version to verify tests.
  python --version
  # Output the chill version to verify tests.
  echo "Chill $current_chill_version"
  exit
fi

echo "INFO $0: Installing chill dependencies"
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

ln -s -f /usr/bin/python3 /usr/bin/python

# Output the python version to verify tests.
python --version
# TODO Use a venv and not root when using pip install
python -m pip install --upgrade --quiet pip
echo "INFO $0: Installing chill"

# TODO Should install from local /var/lib/chillbox/python directory
# python -m pip install --quiet --disable-pip-version-check \
#   --no-index --find-links /var/lib/chillbox/python \
#   chill
apk add git
python -m pip install --quiet --disable-pip-version-check \
  'git+https://github.com/jkenlooper/chill.git@develop#egg=chill'

# Output the chill version to verify tests.
current_chill_version="$(chill --version)"
echo "Chill $current_chill_version"
