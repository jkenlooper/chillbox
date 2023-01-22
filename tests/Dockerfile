# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-05-22" label: "bats/bats base image" interval: "+4 months"
# docker pull bats/bats:1.8.2
# docker image ls --digests bats/bats
FROM bats/bats:1.8.2@sha256:e83f0ac8b0f3e0369ddd740a543f1b9bc90ecb5c616450a7b9538c7f786f0ca2

RUN <<DEPENDENCIES
apk update
apk add \
  -q --no-progress \
  shellcheck \
  mandoc man-pages \
  jq \
  gettext \
  coreutils \
  gnupg gnupg-dirmngr \
  unzip
DEPENDENCIES

RUN <<BATS_HELPERS

set -o errexit

workdir=$(pwd)
tmpdir=$(mktemp -d)

# UPKEEP due: "2023-05-22" label: "bats-support" interval: "+4 months"
# https://github.com/bats-core/bats-support/releases
bats_support_version="0.3.0"
bats_support_checksum="417a8054462a44a6f46e375526cc1c920bae54ea76ddec3ff46603fe68bdb5c58f51bfb1c7e066347a3b71ff4d43986fd5157eb55151e0c4b5d189d81282ea14"
wget -O "$tmpdir/bats-support.tar.gz" \
  "https://github.com/bats-core/bats-support/archive/refs/tags/v${bats_support_version}.tar.gz"
sha512sum $tmpdir/bats-support.tar.gz
echo "${bats_support_checksum}  $tmpdir/bats-support.tar.gz" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$tmpdir/bats-support.tar.gz" "$tmpdir/bats-support.tar.gz.INVALID" \
    && exit 1 \
    )
mkdir -p /opt/bats-support
cd /opt/bats-support
tar x -z -f $tmpdir/bats-support.tar.gz --strip-components 1
cd $workdir

# UPKEEP due: "2023-05-22" label: "bats-assert" interval: "+4 months"
# https://github.com/bats-core/bats-assert/releases
bats_assert_checksum="797689b91df5018b717c09578e1c0f6fea11f344c2e5985ec5eaca89bab39aafa7d88b31043a34576bcdf0ab5cf160c9624ee3167bd0854d7b16aa947b3928e4"
bats_assert_version="2.1.0"
wget -O "$tmpdir/bats-assert.tar.gz" \
  "https://github.com/bats-core/bats-assert/archive/refs/tags/v${bats_assert_version}.tar.gz"
sha512sum $tmpdir/bats-assert.tar.gz
echo "${bats_assert_checksum}  $tmpdir/bats-assert.tar.gz" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$tmpdir/bats-assert.tar.gz" "$tmpdir/bats-assert.tar.gz.INVALID" \
    && exit 1 \
    )
mkdir -p /opt/bats-assert
cd /opt/bats-assert
tar x -z -f $tmpdir/bats-assert.tar.gz --strip-components 1
cd $workdir

# UPKEEP due: "2023-05-22" label: "bats-mock" interval: "+4 months"
# https://github.com/grayhemp/bats-mock/commits/master
bats_mock_checksum="92dc217f349a240e1373a2a5ac6c6d579321739087e6aae8f2661777193e456036f812562c08a55391f01831219429caa2d3a771acd21cf1482834328ae70996"
bats_mock_latest_commit="48fce74482a4d2bb879b904ccab31b6bc98e3224"
wget -O "$tmpdir/bats-mock.zip" \
  "https://github.com/grayhemp/bats-mock/archive/${bats_mock_latest_commit}.zip"
sha512sum "$tmpdir/bats-mock.zip"
echo "${bats_mock_checksum}  $tmpdir/bats-mock.zip" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$tmpdir/bats-mock.zip" "$tmpdir/bats-mock.zip.INVALID" \
    && exit 1 \
    )
mkdir -p /opt/bats-mock
cd /opt/bats-mock
unzip $tmpdir/bats-mock.zip
find . -path './bats-mock-*' -depth -mindepth 2 -maxdepth 2 -exec mv {} ./ \;
rmdir bats-mock-*
cd $workdir

BATS_HELPERS
