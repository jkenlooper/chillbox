#!/usr/bin/env sh

set -o errexit

tmp_artifact="$1"

export tmp_artifact=${tmp_artifact}
test -n "${tmp_artifact}" || (echo "ERROR $0: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $0: The $tmp_artifact is not a file" && exit 1)
echo "INFO $0: Using tmp_artifact '${tmp_artifact}'"

export slugname=${slugname}
test -n "${slugname}" || (echo "ERROR $0: slugname variable is empty" && exit 1)
echo "INFO $0: Using slugname '${slugname}'"

export slugdir=${slugdir}
test -n "${slugdir}" || (echo "ERROR $0: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $0: slugdir should be a directory" && exit 1)
test -d "$(dirname "${slugdir}")" || (echo "ERROR $0: parent directory of slugdir should be a directory" && exit 1)
echo "INFO $0: Using slugdir '${slugdir}'"


# Extract just the nginx directory from the tmp_artifact
rm -rf "$slugname/nginx.bak.tar.gz"
test -e "$slugname/nginx" \
  && tar c -z -f "$slugname/nginx.bak.tar.gz" "$slugname/nginx"
rm -rf "$slugname/nginx"
tar x -z -f "$tmp_artifact" "$slugname/nginx"
chown -R "$slugname":"$slugname" "$slugdir"
echo "INFO $0: Extracted nginx service for $slugname"
