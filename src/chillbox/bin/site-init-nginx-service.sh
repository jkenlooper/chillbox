#!/usr/bin/env sh

set -o errexit

tmp_artifact="$1"
slugdir="$2"

test -n "${tmp_artifact}" || (echo "ERROR $0: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $0: The $tmp_artifact is not a file" && exit 1)
echo "INFO $0: Using tmp_artifact '${tmp_artifact}'"

test -n "${SLUGNAME}" || (echo "ERROR $0: SLUGNAME variable is empty" && exit 1)
echo "INFO $0: Using slugname '${SLUGNAME}'"

test -n "${slugdir}" || (echo "ERROR $0: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $0: slugdir should be a directory" && exit 1)
test -d "$(dirname "${slugdir}")" || (echo "ERROR $0: parent directory of slugdir should be a directory" && exit 1)
echo "INFO $0: Using slugdir '${slugdir}'"


# Extract just the nginx directory from the tmp_artifact
rm -f "$SLUGNAME/nginx.bak.tar.gz"
test -e "$SLUGNAME/nginx" \
  && tar c -z -f "$SLUGNAME/nginx.bak.tar.gz" "$SLUGNAME/nginx"
rm -rf "$SLUGNAME/nginx"
tar x -z -f "$tmp_artifact" "$SLUGNAME/nginx"
chown -R "$SLUGNAME":"$SLUGNAME" "$slugdir"
echo "INFO $0: Extracted nginx service for $SLUGNAME"
