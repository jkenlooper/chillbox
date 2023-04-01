#!/usr/bin/env sh

set -o errexit

# This script is isolated so other applications that are being developed locally
# in a container can install the same package dependencies as the chillbox
# server. See the referenced file in https://github.com/jkenlooper/cookiecutters

# Include build tools
apk add --no-cache \
  -q --no-progress \
  build-base \
  gcc \
  musl-dev \
  cmake

# Support Python services
apk add --no-cache \
  -q --no-progress \
  libffi-dev \
  py3-pip \
  python3 \
  python3-dev

# Support Python Pillow for image manipulation
# https://pillow.readthedocs.io/en/latest/installation.html#building-from-source
apk add --no-cache \
  -q --no-progress \
  freetype \
  freetype-dev \
  fribidi \
  fribidi-dev \
  harfbuzz \
  harfbuzz-dev \
  jpeg \
  jpeg-dev \
  lcms2 \
  lcms2-dev \
  libjpeg \
  openjpeg \
  openjpeg-dev \
  tcl \
  tcl-dev \
  tiff \
  tiff-dev \
  tk \
  tk-dev \
  zlib \
  zlib-dev

# UPKEEP due: "2025-03-11" label: "libspatialindex for Python Rtree" interval: "+2 years"
# Alpine Linux currently doesn't have spatialindex available as a package.
# Opting to install manually at this point.
# TODO: Include libspatialindex tar.gz in the chillbox artifact instead?
# https://github.com/libspatialindex/libspatialindex/releases
spatialindex_sha512sum="519d1395de01ffc057a0da97a610c91b1ade07772f54fce521553aafd1d29b58df9878bb067368fd0a0990049b6abce0b054af7ccce6bf123b835f5c7ed80eec"
spatialindex_version="1.9.3"
spatialindex_release_url="https://github.com/libspatialindex/libspatialindex/releases/download/$spatialindex_version/spatialindex-src-$spatialindex_version.tar.gz"
spatialindex_tar="$(basename "$spatialindex_release_url")"
spatialindex_tmp_dir="$(mktemp -d)"
wget -P "$spatialindex_tmp_dir" -O "$spatialindex_tmp_dir/$spatialindex_tar" "$spatialindex_release_url"
sha512sum "$spatialindex_tmp_dir/$spatialindex_tar"
echo "$spatialindex_sha512sum  $spatialindex_tmp_dir/$spatialindex_tar" | sha512sum -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$spatialindex_tmp_dir/$spatialindex_tar" "$spatialindex_tmp_dir/$spatialindex_tar.INVALID" \
    && exit 1 \
    )
tar x -o -f "$spatialindex_tmp_dir/$spatialindex_tar" -C "$spatialindex_tmp_dir" --strip-components 1
(cd "$spatialindex_tmp_dir"
  cmake "$spatialindex_tmp_dir"
  make -C "$spatialindex_tmp_dir"
  make -C "$spatialindex_tmp_dir" install
)
rm -rf "$spatialindex_tmp_dir"

# Chill uses sqlite
apk add --no-cache \
  -q --no-progress \
  sqlite

# Other common tools when working with images
apk add --no-cache \
  -q --no-progress \
  imagemagick \
  optipng \
  potrace \
  rsvg-convert

mkdir -p /var/lib/chillbox/python
# Support Python services managed by Gunicorn
# UPKEEP due: "2024-03-11" label: "Python gunicorn and gevent" interval: "+1 years"
# https://pypi.org/project/gunicorn/
gunicorn_version="20.1.0"
# Only download to a directory to allow the pip install to happen later with
# a set --find-links option.
python -m pip download \
  --disable-pip-version-check \
  --exists-action i \
  --no-build-isolation \
  --destination-directory /var/lib/chillbox/python \
  'gunicorn[gevent,setproctitle]'=="$gunicorn_version"
