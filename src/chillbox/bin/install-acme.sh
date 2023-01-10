#!/usr/bin/env sh

set -o errexit


TECH_EMAIL=${TECH_EMAIL:-$2}
test -n "${TECH_EMAIL}" || (echo "ERROR $0: TECH_EMAIL variable is empty" && exit 1)
echo "INFO $0: Using TECH_EMAIL '${TECH_EMAIL}'"

ACME_SERVER=${ACME_SERVER:-$1}
test -n "${ACME_SERVER}" || (echo "ERROR $0: ACME_SERVER variable is empty" && exit 1)
echo "INFO $0: Using ACME_SERVER '${ACME_SERVER}'"

# UPKEEP due: "2023-04-10" label: "Update acme.sh version" interval: "+3 months"
# https://github.com/acmesh-official/acme.sh/releases
acme_sh_version="3.0.5"
acme_sh_checksum="882768c84182a8b11f4f315a9b429cd84399145a97b64772a42e0c7fc478c6c5f93a6c73289410b4d2108786a7c275e99f2e47991bdca315fd7d80a4282eefc9"
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

# acme.sh requires the 'socat' command

#mkdir -p /etc/acmesh
#mkdir -p /etc/acmesh/certs

echo "acme.sh version: $(acme.sh --version | xargs)"

# Allow tests to skip the rest of the script
test "${SKIP_INSTALL_ACMESH}" = "y" && echo "Skipping 'acme.sh --install ...' step" && exit 0

apk add openssl

acme.sh --install \
  --email "$TECH_EMAIL" \
  --server "$ACME_SERVER" \
  --no-profile
  #--home /etc/acmesh \
  #--accountconf /etc/acmesh/account.conf \
  #--cert-home /etc/acmesh/certs

