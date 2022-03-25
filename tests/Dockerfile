# syntax=docker/dockerfile:1.3.0-labs

# docker pull bats/bats:1.6.0
# docker image ls --digests bats/bats
FROM bats/bats:1.6.0@sha256:129acefb6d37565d9a459f716c9cfea7409d76521bb576eebda5174521e831f9

ARG BATS_SUPPORT_CHECKSUM="5a0e0f38490cfe30e1c146ea712c1146"
ARG BATS_ASSERT_CHECKSUM="3e421df7ec578728d6bc7e47ab4cbdd8"
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

BATS_HELPERS
