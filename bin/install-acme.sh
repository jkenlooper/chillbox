#!/usr/bin/env sh

set -o errexit


TECH_EMAIL=${TECH_EMAIL}
test -n "${TECH_EMAIL}" || (echo "ERROR $0: TECH_EMAIL variable is empty" && exit 1)
echo "INFO $0: Using TECH_EMAIL '${TECH_EMAIL}'"

LETS_ENCRYPT_SERVER=${LETS_ENCRYPT_SERVER}
test -n "${LETS_ENCRYPT_SERVER}" || (echo "ERROR $0: LETS_ENCRYPT_SERVER variable is empty" && exit 1)
test "${LETS_ENCRYPT_SERVER}" = "letsencrypt" \
  || test "${LETS_ENCRYPT_SERVER}" = "letsencrypt_test" \
  || (echo "ERROR $0: LETS_ENCRYPT_SERVER variable should be either letsencrypt or letsencrypt_test" && exit 1)
echo "INFO $0: Using LETS_ENCRYPT_SERVER '${LETS_ENCRYPT_SERVER}'"

ACME_SH_VERSION=${ACME_SH_VERSION:-$1}
test -n "${ACME_SH_VERSION}" || (echo "ERROR $0: ACME_SH_VERSION variable is empty" && exit 1)

echo "INFO $0: Installing letsencrypt acme.sh version $ACME_SH_VERSION"

mkdir -p /usr/local/bin/
cd /usr/local/bin/
tmp_acme_tar=$(mktemp)
wget -O $tmp_acme_tar https://github.com/acmesh-official/acme.sh/archive/refs/tags/$ACME_SH_VERSION.tar.gz
tmp_md5sum=$(mktemp)
echo "21f4b4b88df5d7fb89bf15df9a8a8c94  $tmp_acme_tar" > $tmp_md5sum
md5sum -c $tmp_md5sum
tar x -z -f $tmp_acme_tar --strip-components 1 acme.sh-$ACME_SH_VERSION/acme.sh
#mkdir -p /etc/acmesh
#mkdir -p /etc/acmesh/certs

echo "acme.sh version: $(acme.sh --version | xargs)"

# Allow tests to skip the rest of the script
test "${SKIP_INSTALL_ACMESH}" = "y" && echo "Skipping 'acme.sh --install ...' step" && exit 0

apk add \
  openssl

# TODO review bin/certs.sh script
acme.sh --install \
  --email $TECH_EMAIL \
  --server $LETS_ENCRYPT_SERVER \
  --no-profile
  #--home /etc/acmesh \
  #--accountconf /etc/acmesh/account.conf \
  #--cert-home /etc/acmesh/certs
