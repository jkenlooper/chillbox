# syntax=docker/dockerfile:1.3.0-labs

# docker pull bats/bats:1.6.0
# docker image ls --digests bats/bats
FROM bats/bats:1.6.0@sha256:129acefb6d37565d9a459f716c9cfea7409d76521bb576eebda5174521e831f9

RUN <<DEPENDENCIES
apk update
apk add \
  -q --no-progress \
  shellcheck \
  mandoc man-pages \
  jq \
  gettext \
  unzip
DEPENDENCIES

ARG BATS_SUPPORT_CHECKSUM="5a0e0f38490cfe30e1c146ea712c1146"
ARG BATS_ASSERT_CHECKSUM="3e421df7ec578728d6bc7e47ab4cbdd8"
ARG BATS_MOCK_CHECKSUM="2007b5cc15c4b07187fe2eab831ed8a0"
RUN <<BATS_HELPERS

set -o errexit

workdir=$(pwd)
tmpdir=$(mktemp -d)

wget -O $tmpdir/bats-support.tar.gz \
  https://github.com/bats-core/bats-support/archive/refs/tags/v0.3.0.tar.gz
md5sum $tmpdir/bats-support.tar.gz
echo "${BATS_SUPPORT_CHECKSUM}  $tmpdir/bats-support.tar.gz" | md5sum -c
mkdir -p /opt/bats-support
cd /opt/bats-support
tar x -z -f $tmpdir/bats-support.tar.gz --strip-components 1
cd $workdir

wget -O $tmpdir/bats-assert.tar.gz \
  https://github.com/bats-core/bats-assert/archive/refs/tags/v2.0.0.tar.gz
md5sum $tmpdir/bats-assert.tar.gz
echo "${BATS_ASSERT_CHECKSUM}  $tmpdir/bats-assert.tar.gz" | md5sum -c
mkdir -p /opt/bats-assert
cd /opt/bats-assert
tar x -z -f $tmpdir/bats-assert.tar.gz --strip-components 1
cd $workdir

wget -O $tmpdir/bats-mock.zip \
  https://github.com/grayhemp/bats-mock/archive/48fce74482a4d2bb879b904ccab31b6bc98e3224.zip
md5sum $tmpdir/bats-mock.zip
echo "${BATS_MOCK_CHECKSUM}  $tmpdir/bats-mock.zip" | md5sum -c
mkdir -p /opt/bats-mock
cd /opt/bats-mock
unzip $tmpdir/bats-mock.zip
find . -path './bats-mock-*' -depth -mindepth 2 -maxdepth 2 -exec mv {} ./ \;
rmdir bats-mock-*
cd $workdir

BATS_HELPERS
