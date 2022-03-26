#!/usr/bin/env sh

set -o errexit

apk add \
  -q --no-progress \
  nginx
nginx -v

# gettext includes envsubst
apk add \
  -q --no-progress \
  gettext

# Support parsing json files with jq
apk add \
  -q --no-progress \
  jq
jq --version

# Support Python Pillow
apk add \
  -q --no-progress \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  zlib \
  openjpeg \
  libjpeg \
  tiff \
  freetype \
  fribidi \
  harfbuzz \
  jpeg \
  lcms2 \
  tcl \
  tk \
  freetype-dev \
  fribidi-dev \
  harfbuzz-dev \
  jpeg-dev \
  lcms2-dev \
  openjpeg-dev \
  tcl-dev \
  tiff-dev \
  tk-dev \
  zlib-dev

echo "Finished $0"
