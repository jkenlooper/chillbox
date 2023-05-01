#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

tmp_artifact="$1"
slugdir="$2"

test -n "${tmp_artifact}" || (echo "ERROR $script_name: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $script_name: The $tmp_artifact is not a file" && exit 1)
echo "INFO $script_name: Using tmp_artifact '${tmp_artifact}'"

test -n "${SLUGNAME}" || (echo "ERROR $script_name: SLUGNAME variable is empty" && exit 1)
echo "INFO $script_name: Using slugname '${SLUGNAME}'"

test -n "${slugdir}" || (echo "ERROR $script_name: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $script_name: slugdir should be a directory" && exit 1)
test -d "$(dirname "${slugdir}")" || (echo "ERROR $script_name: parent directory of slugdir should be a directory" && exit 1)
echo "INFO $script_name: Using slugdir '${slugdir}'"


# Extract just the nginx directory from the tmp_artifact
rm -f "$SLUGNAME/nginx.bak.tar.gz"
test -e "$SLUGNAME/nginx" \
  && tar c -z -f "$SLUGNAME/nginx.bak.tar.gz" "$SLUGNAME/nginx"
rm -rf "$SLUGNAME/nginx"
tar x -z -f "$tmp_artifact" "$SLUGNAME/nginx"
chown -R "$SLUGNAME":"$SLUGNAME" "$slugdir"
echo "INFO $script_name: Extracted nginx service for $SLUGNAME"
