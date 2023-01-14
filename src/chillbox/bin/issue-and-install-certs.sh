#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

ACME_SERVER="${ACME_SERVER:-''}"
test -n "${ACME_SERVER}" || (echo "ERROR $script_name: ACME_SERVER variable is empty" && exit 1)
echo "INFO $script_name: Using ACME_SERVER '${ACME_SERVER}'"

echo "TODO $script_name: Not implemented."
exit 1

