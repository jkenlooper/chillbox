#!/usr/bin/env sh

set -o errexit

slugname=site1

projectdir="$(dirname "$(dirname "$(realpath "$0")")")"

# archive file path should be absolute
archive="$(realpath "$1")"
echo "$archive" | grep -q "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/$slugname"

cd "$projectdir/chill"
mkdir -p "$tmpdir/$slugname/chill"
cp -R documents queries templates chill-data.yaml site.cfg VERSION "$tmpdir/$slugname/chill/"

cd "$projectdir/llama"
mkdir -p "$tmpdir/$slugname/llama"
cp -R documents queries templates chill-data.yaml site.cfg VERSION "$tmpdir/$slugname/llama/"

cd "$projectdir/api"
mkdir -p "$tmpdir/$slugname/api"
cp -R api-bridge.secrets.Dockerfile "$tmpdir/$slugname/api/"
cp -R pyproject.toml README.md MANIFEST.in requirements.txt setup.cfg setup.py src "$tmpdir/$slugname/api/"

cd "$projectdir/nginx"
mkdir -p "$tmpdir/$slugname/nginx"
cp -R root templates "$tmpdir/$slugname/nginx/"

cd "$tmpdir"
archive_dir="$(dirname "$archive")"
mkdir -p "$archive_dir"
tar c \
  -h \
  -z \
  -f "${archive}" \
  "$slugname"

# Clean up
rm -rf "${tmpdir}"
