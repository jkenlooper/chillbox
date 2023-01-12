#!/usr/bin/env sh

set -o errexit

ACME_SERVER="${ACME_SERVER:-''}"
test -n "${ACME_SERVER}" || (echo "ERROR $0: ACME_SERVER variable is empty" && exit 1)
echo "INFO $0: Using ACME_SERVER '${ACME_SERVER}'"

echo "TODO $0: Not implemented."
exit 1

