#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

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

install_deno() {
  # UPKEEP due: "2023-02-07" label: "Deno javascript runtime" interval: "+5 months"
  # https://github.com/denoland/deno/releases
  deno_version="v1.25.1"

  tmp_zip="$(mktemp)"

  # Installing deno for all users
  bin_dir="/usr/local/bin"

  # Only care about linux for now. If needing to support install of deno for
  # others; then use https://deno.land/install.sh or alternatives.
  wget -O "$tmp_zip" "https://github.com/denoland/deno/releases/download/$deno_version/deno-x86_64-unknown-linux-gnu.zip"

  mkdir -p "$bin_dir"
  unzip -o -d "$bin_dir" "$tmp_zip"
  rm -f "$tmp_zip"
  chmod +x "$bin_dir/deno"

  command -v deno
  deno_path_sanity_check="$(command -v deno)"
  test "$bin_dir/deno" = "$deno_path_sanity_check" || (echo "ERROR $script_name: deno in PATH is not the same as the downloaded one." && exit 1)

  deno --version
}
command -v deno || install_deno

echo "Finished $script_name"
