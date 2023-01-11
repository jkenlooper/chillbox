#!/usr/bin/env sh

set -o errexit


TECH_EMAIL=${TECH_EMAIL:-$2}
test -n "${TECH_EMAIL}" || (echo "ERROR $0: TECH_EMAIL variable is empty" && exit 1)
echo "INFO $0: Using TECH_EMAIL '${TECH_EMAIL}'"

ACME_SERVER=${ACME_SERVER:-$1}
test -n "${ACME_SERVER}" || (echo "ERROR $0: ACME_SERVER variable is empty" && exit 1)
echo "INFO $0: Using ACME_SERVER '${ACME_SERVER}'"

python -m pip install --quiet --disable-pip-version-check \
  --no-index --find-links /var/lib/chillbox/python \
  certbot

# TODO register the TECH_EMAIL with the ACME_SERVER here?
