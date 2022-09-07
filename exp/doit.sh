#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

# UPKEEP due: "2023-02-07" label: "Deno javascript runtime" interval: "+5 months"
# https://github.com/denoland/deno/releases
deno_version="v1.25.1"

tmp_zip="$(mktemp)"

# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
bin_dir="$HOME/.local/bin"

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
