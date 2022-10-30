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

# TODO With Alpine Linux 3.16.2 it is not compatible with the previous hack of
# updating glibc which was originally done for installing the aws-cli.
# Commenting out a total WIP of an attempt that got over my head here. In short,
# it is probably not a good idea to mess around with changing the glibc on the
# system.
#
## # Add glibc for use with deno. Does not work here.
## # https://wiki.alpinelinux.org/wiki/Running_glibc_programs
## # apk add gcompat
##
## # UPKEEP due: "2023-01-10" label: "Alpine Linux add glibc compatibility" interval: "+3 months"
## # Thanks to https://github.com/aws/aws-cli/issues/4685#issuecomment-615872019
## # This needs to be compatible with the current Alpine Linux version.
## # https://github.com/sgerrand/alpine-pkg-glibc
## GLIBC_VER=2.36
## tmp_glibc_install_dir="$(mktemp -d)"
## # install glibc compatibility for alpine
## apk --no-cache add binutils
##
## # TODO build and install glibc manually?
## # http://ftp.gnu.org/gnu/glibc/glibc-2.36.tar.gz
## apk add gawk bison
## # Create a separate dir and ../glibc-2.36/configure
## # https://sourceware.org/glibc/wiki/Testing/Builds
##
## DESTDIR=/usr
## wget -q http://ftp.gnu.org/gnu/glibc/glibc-2.36.tar.gz -O "$tmp_glibc_install_dir/glibc-2.36.tar.gz"
## mkdir "$tmp_glibc_install_dir/glibc"
## tar x -f "$tmp_glibc_install_dir/glibc-2.36.tar.gz" -C "$tmp_glibc_install_dir/glibc" --strip-components 1
## cd $tmp_glibc_install_dir
## mkdir -p "$tmp_glibc_install_dir/build/glibc"
## cd "$tmp_glibc_install_dir/build/glibc"
## $tmp_glibc_install_dir/glibc/configure --prefix=/usr
## make
## make check
## make install DESTDIR=${DESTDIR}
##
## tmp_linux_kernel_torvalds="$(mktemp -d)"
## wget -q https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-6.0.tar.gz -O "$tmp_linux_kernel_torvalds/linux-6.0.tar.gz"
## mkdir "$tmp_linux_kernel_torvalds/linux"
## tar x -f "$tmp_linux_kernel_torvalds/linux-6.0.tar.gz" -C "$tmp_linux_kernel_torvalds/linux" --strip-components 1
## cd "$tmp_linux_kernel_torvalds/linux"
## make headers_install INSTALL_HDR_PATH="/usr"
##
## wget -q https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -O /etc/apk/keys/sgerrand.rsa.pub
## wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-${GLIBC_VER}.apk -O "$tmp_glibc_install_dir/glibc-${GLIBC_VER}.apk"
## wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk -O "$tmp_glibc_install_dir/glibc-bin-${GLIBC_VER}.apk"
##
## wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-i18n-${GLIBC_VER}.apk -O "$tmp_glibc_install_dir/glibc-i18n-${GLIBC_VER}.apk"
##
## # Need to use --force-overwrite to get around issue of
## # trying to overwrite etc/nsswitch.conf owned by alpine-baselayout-data-3.2.0-r23.
## # https://github.com/sgerrand/alpine-pkg-glibc/issues/185
## apk add --no-cache \
##   --force-overwrite \
##   "$tmp_glibc_install_dir/glibc-${GLIBC_VER}.apk" \
##   "$tmp_glibc_install_dir/glibc-bin-${GLIBC_VER}.apk" \
##   "$tmp_glibc_install_dir/glibc-i18n-${GLIBC_VER}.apk"
## apk fix \
##   --force-overwrite \
##   alpine-baselayout-data
## /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8
##
## rm -rf "$tmp_glibc_install_dir"

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
# TODO Fix deno install to use muslc instead of glibc.
# https://github.com/denoland/deno/issues/3711
echo "Skipping deno install. It is currently not compatible with the current version of Alpine Linux."
#command -v deno || install_deno

echo "Finished $script_name"
