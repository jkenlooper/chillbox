#!/usr/bin/env sh

set -o errexit

install_dir="${1:-/usr/local/bin}"

# UPKEEP due: "2023-07-22" label: "s5cmd for s3 object storage" interval: "+6 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_checksum="379d054f434bd1fbd44c0ae43a3f0f11a25e5c23fd9d7184ceeae1065e74e94ad6fa9e42dadd32d72860b919455e22cd2100b6315fd610d8bb4cfe81474621b4"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
sha512sum "$s5cmd_tmp_dir/$s5cmd_tar"
echo "$s5cmd_checksum  $s5cmd_tmp_dir/$s5cmd_tar" | sha512sum -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_tmp_dir/$s5cmd_tar.INVALID" \
    && exit 1 \
    )
tar x -o -f "$s5cmd_tmp_dir/$s5cmd_tar" -C "$install_dir" s5cmd
rm -rf "$s5cmd_tmp_dir"
