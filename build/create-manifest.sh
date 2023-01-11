#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"

# Make a clean clone of the working directory to avoid including any files to
# the manifest that are not checked in.
tmp_dir="$(mktemp -d)"
git clone --depth 1 --single-branch "file://$working_dir" "$tmp_dir"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

cd "$tmp_dir"

# The python packages are not tracked by git and need to be created.
"$working_dir/build/update-dep.sh"
cp -R "$working_dir"/src/chillbox/dep/* "$tmp_dir/src/chillbox/dep/"

./build/list-manifest-files.sh > "$working_dir/build/MANIFEST"
