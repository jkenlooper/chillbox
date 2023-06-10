#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

# Prevent reinstalling chill by checking the version.
current_chill_version="$(command -v chill > /dev/null 2>&1 && chill --version || printf "")"
if [ -n "$current_chill_version" ]; then
  echo "INFO $script_name: Skipping reinstall of chill version $current_chill_version"
  # Output the python version to verify tests.
  python --version
  # Output the chill version to verify tests.
  echo "Chill $current_chill_version"
  exit
fi

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

# TODO: Don't install chill as root user.

# Output the python version to verify tests.
python --version
# TODO Use a venv and not root when using pip install
python -m pip install --upgrade --quiet pip
echo "INFO $script_name: Installing chill"

python -m pip install --quiet --disable-pip-version-check \
  --no-index --find-links /var/lib/chillbox/python \
  'gunicorn[setproctitle]' \
  Frozen-Flask \
  docopt \
  Babel \
  click \
  Flask \
  Flask-Markdown \
  humanize \
  importlib-metadata \
  itsdangerous \
  Jinja2 \
  Markdown \
  MarkupSafe \
  pytz \
  PyYAML \
  Werkzeug \
  zipp

python -m pip install --quiet --disable-pip-version-check \
  --no-index --find-links /var/lib/chillbox/python \
  chill
# TODO Should install from local /var/lib/chillbox/python directory
# python -m pip install --quiet --disable-pip-version-check \
#   --no-index --find-links /var/lib/chillbox/python \
#   chill
#apk add git
#python -m pip install --quiet --disable-pip-version-check \
#  'git+https://github.com/jkenlooper/chill.git@develop#egg=chill'

# Output the chill version to verify tests.
current_chill_version="$(chill --version)"
echo "Chill $current_chill_version"
