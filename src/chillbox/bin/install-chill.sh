#!/usr/bin/env sh

set -o errexit

# UPKEEP due: "2022-11-09" label: "chill version" interval: "+4 months"
chill_version="0.9.0"

# Prevent reinstalling chill by checking the version.
current_chill_version="$(command -v chill > /dev/null && chill --version || printf "")"
if [ "$current_chill_version" = "$chill_version" ]; then
  echo "INFO $0: Skipping reinstall of chill version $chill_version"
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
pip install --upgrade --quiet pip
echo "INFO $0: Installing chill version $chill_version"
python -m pip install --quiet --disable-pip-version-check "chill==$chill_version"

# Output the chill version to verify tests.
current_chill_version="$(chill --version)"
echo "Chill $current_chill_version"
