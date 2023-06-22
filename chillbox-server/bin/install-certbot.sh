#!/usr/bin/env sh

set -o errexit

cmd="certbot"
has_cmd="$(command -v "$cmd" || printf "")"
if [ -n "$has_cmd" ]; then
  echo "Already installed $cmd"
  exit 0
fi

# TODO Don't pip install certbot as root
python -m pip install --quiet --disable-pip-version-check \
  --no-index --find-links /var/lib/chillbox/python \
  certbot
