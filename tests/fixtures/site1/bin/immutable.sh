#!/usr/bin/env sh

set -o errexit

slugname=site1

projectdir="$(dirname "$(dirname "$(realpath "$0")")")"

# Wouldn't normally use the Makefile for a hash, but this is just for testing.
immutable_example_hash="$(md5sum "$projectdir/Makefile" | cut -d' ' -f1)"

# archive file path should be absolute
archive="$(realpath "$1")"
echo "$archive" | grep -q "\.tar\.gz$" || (echo "First arg should be an archive file ending with .tar.gz" && exit 1)

tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/$slugname"

mkdir -p "$tmpdir/$slugname/immutable-example/$immutable_example_hash"
find "$projectdir/" -type f | sort >  "$tmpdir/$slugname/immutable-example/$immutable_example_hash/man.txt"
echo "file 1 example" > "$tmpdir/$slugname/immutable-example/$immutable_example_hash/file1.txt"
echo "file 2 example" > "$tmpdir/$slugname/immutable-example/$immutable_example_hash/file2.txt"

archive_dir="$(dirname "$archive")"
mkdir -p "$archive_dir"
tar c \
  -C "$tmpdir" \
  -h \
  -z \
  -f "${archive}" \
  "$slugname"

# Clean up
rm -rf "${tmpdir}"
