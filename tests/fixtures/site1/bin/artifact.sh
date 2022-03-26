#!/usr/bin/env bash
set -eu -o pipefail

slugname=site1

# archive file path should be absolute
ARCHIVE=$(realpath $1)
echo $ARCHIVE | grep --quiet "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

TMPDIR=$(mktemp --directory);
mkdir -p $TMPDIR/$slugname

cd chill
mkdir -p $TMPDIR/$slugname/chill
cp -R documents queries templates chill-data.yaml site.cfg VERSION $TMPDIR/$slugname/chill/
cd - > /dev/null

cd api
mkdir -p $TMPDIR/$slugname/api
cp -R pyproject.toml README.md MANIFEST.in requirements.txt setup.cfg setup.py src $TMPDIR/$slugname/api/
cd - > /dev/null

cd nginx
mkdir -p $TMPDIR/$slugname/nginx
cp -R root templates $TMPDIR/$slugname/nginx/
cd - > /dev/null

cd "$TMPDIR";
tar --dereference \
  --create \
  --auto-compress \
  --file "${ARCHIVE}" $slugname;
cd - > /dev/null

# Clean up
rm -rf "${TMPDIR}";
