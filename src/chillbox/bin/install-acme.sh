#!/usr/bin/env sh

set -o errexit


TECH_EMAIL=${TECH_EMAIL:-$3}
test -n "${TECH_EMAIL}" || (echo "ERROR $0: TECH_EMAIL variable is empty" && exit 1)
echo "INFO $0: Using TECH_EMAIL '${TECH_EMAIL}'"

LETS_ENCRYPT_SERVER=${LETS_ENCRYPT_SERVER:-$2}
test -n "${LETS_ENCRYPT_SERVER}" || (echo "ERROR $0: LETS_ENCRYPT_SERVER variable is empty" && exit 1)
test "${LETS_ENCRYPT_SERVER}" = "letsencrypt" \
  || test "${LETS_ENCRYPT_SERVER}" = "letsencrypt_test" \
  || (echo "ERROR $0: LETS_ENCRYPT_SERVER variable should be either letsencrypt or letsencrypt_test" && exit 1)
echo "INFO $0: Using LETS_ENCRYPT_SERVER '${LETS_ENCRYPT_SERVER}'"

# UPKEEP due: "2022-07-18" label: "Update acme.sh version" interval: "+3 months"
# https://github.com/acmesh-official/acme.sh/releases
acme_sh_version="3.0.4"
acme_sh_checksum="919987ac026366d245fa2730edf1212deafb051129811f35b482a30af9b0034a802baa218a35048e030795127cfeae03b4c3d4f12e580cd82edbacdd72e588e7"
echo "INFO $0: Installing letsencrypt acme.sh version $acme_sh_version"
mkdir -p /usr/local/bin/
cd /usr/local/bin/
tmp_acme_tar=$(mktemp)
wget "https://github.com/acmesh-official/acme.sh/archive/refs/tags/$acme_sh_version.tar.gz" \
  -O "$tmp_acme_tar"
sha512sum "$tmp_acme_tar"
echo "$acme_sh_checksum  $tmp_acme_tar" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$tmp_acme_tar" "$tmp_acme_tar.INVALID" \
    && exit 1 \
    )
tar x -z -f "$tmp_acme_tar" --strip-components 1 "acme.sh-$acme_sh_version/acme.sh"

#mkdir -p /etc/acmesh
#mkdir -p /etc/acmesh/certs

echo "acme.sh version: $(acme.sh --version | xargs)"

# Allow tests to skip the rest of the script
test "${SKIP_INSTALL_ACMESH}" = "y" && echo "Skipping 'acme.sh --install ...' step" && exit 0

apk add \
  openssl

acme.sh --install \
  --email "$TECH_EMAIL" \
  --server "$LETS_ENCRYPT_SERVER" \
  --no-profile
  #--home /etc/acmesh \
  #--accountconf /etc/acmesh/account.conf \
  #--cert-home /etc/acmesh/certs

