#!/usr/bin/env bash
set -eu -o pipefail

slugname=site1

# archive file path should be absolute
ARCHIVE=$(realpath $1)
echo $ARCHIVE | grep --quiet "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

TMPDIR=$(mktemp --directory);
mkdir -p $TMPDIR/$slugname
tmpname="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 || printf '')"

cd example
touch file1.txt
touch file2.txt
mkdir -p $TMPDIR/$slugname/example
cp file*.txt $TMPDIR/$slugname/example/
cd - > /dev/null

cd "$TMPDIR";
tar --dereference \
  --create \
  --auto-compress \
  --file "${ARCHIVE}" $slugname;
cd - > /dev/null

# Clean up
rm -rf "${TMPDIR}";
