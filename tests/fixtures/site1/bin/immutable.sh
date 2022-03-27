#!/usr/bin/env sh

set -o errexit

slugname=site1

projectdir=$(dirname $(dirname $(realpath $0)))

# archive file path should be absolute
ARCHIVE=$(realpath $1)
echo $ARCHIVE | grep -q "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

TMPDIR=$(mktemp -d)
mkdir -p $TMPDIR/$slugname
tmpname="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 || printf '')"

cd $projectdir/example
touch file1.txt
touch file2.txt
mkdir -p $TMPDIR/$slugname/example
cp file*.txt $TMPDIR/$slugname/example/

cd "$TMPDIR"
tar c \
  -h \
  -z \
  -f "${ARCHIVE}" \
  $slugname

# Clean up
rm -rf "${TMPDIR}"
