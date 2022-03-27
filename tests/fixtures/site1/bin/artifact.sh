#!/usr/bin/env sh

set -o errexit

slugname=site1

projectdir=$(dirname $(dirname $(realpath $0)))

# archive file path should be absolute
ARCHIVE=$(realpath $1)
echo $ARCHIVE | grep -q "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

TMPDIR=$(mktemp -d)
mkdir -p $TMPDIR/$slugname

cd $projectdir/chill
mkdir -p $TMPDIR/$slugname/chill
cp -R documents queries templates chill-data.yaml site.cfg VERSION $TMPDIR/$slugname/chill/

cd $projectdir/api
mkdir -p $TMPDIR/$slugname/api
cp -R pyproject.toml README.md MANIFEST.in requirements.txt setup.cfg setup.py src $TMPDIR/$slugname/api/

cd $projectdir/nginx
mkdir -p $TMPDIR/$slugname/nginx
cp -R root templates $TMPDIR/$slugname/nginx/

cd "$TMPDIR"
tar c \
  -h \
  -z \
  -f "${ARCHIVE}" \
  $slugname

# Clean up
rm -rf "${TMPDIR}"
