#!/usr/bin/env sh

set -o errexit

apk add -q --no-progress nginx
nginx -v

# gettext includes envsubst
apk add -q --no-progress gettext

# Support parsing json files with jq
apk add -q --no-progress jq
jq --version

# Support python services and python Pillow
apk add \
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

ln -s -f /usr/bin/python3 /usr/bin/python

echo "Finished $0"
