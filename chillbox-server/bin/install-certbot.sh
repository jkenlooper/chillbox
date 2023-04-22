#!/usr/bin/env sh

set -o errexit

python -m pip install --quiet --disable-pip-version-check \
  --no-index --find-links /var/lib/chillbox/python \
  certbot
