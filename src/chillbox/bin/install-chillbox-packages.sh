#!/usr/bin/env sh

set -o errexit

# This script is isolated so other applications that are being developed locally
# in a container can install the same package dependencies as the chillbox
# server. See the referenced file in https://github.com/jkenlooper/cookiecutters

script_name="$(basename "$0")"

# Support python services and python Pillow
apk add --no-cache \
  -q --no-progress \
  build-base \
  freetype \
  freetype-dev \
  fribidi \
  fribidi-dev \
  gcc \
  harfbuzz \
  harfbuzz-dev \
  jpeg \
  jpeg-dev \
  lcms2 \
  lcms2-dev \
  libffi-dev \
  libjpeg \
  musl-dev \
  openjpeg \
  openjpeg-dev \
  py3-pip \
  python3 \
  python3-dev \
  sqlite \
  tcl \
  tcl-dev \
  tiff \
  tiff-dev \
  tk \
  tk-dev \
  zlib \
  zlib-dev

mkdir -p /var/lib/chillbox/python
# Support python services managed by gunicorn
# UPKEEP due: "2023-03-23" label: "Python gunicorn and gevent" interval: "+3 months"
# https://pypi.org/project/gunicorn/
gunicorn_version="20.1.0"
# Only download to a directory to allow the pip install to happen later with
# a set --find-links option.
/usr/bin/python3 -m pip download \
  --disable-pip-version-check \
  --destination-directory /var/lib/chillbox/python \
  gunicorn[gevent,setproctitle]=="$gunicorn_version"
