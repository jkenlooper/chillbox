#!/usr/bin/env bash
set -eu -o pipefail

set -x

# https://linuxhint.com/debian_frontend_noninteractive/
export DEBIAN_FRONTEND=noninteractive

apt-get --yes update
apt-get --yes upgrade

# TODO: add these to apt-get commands that show anything about existing
# configuration files that need to be overwritten
# -o Dpkg::Options::="--force-confdef" \
# -o Dpkg::Options::="--force-confold" \

apt-get --yes install ssh

apt-get --yes install \
  gnupg2 \
  ca-certificates \
  lsb-release \
  software-properties-common \
  cron \
  make \
  gcc \
  unzip \
  curl

apt-get --yes install \
  python3 \
  python3-dev \
  python3-venv \
  python3-numpy \
  python3-pip \
  python-is-python3 \
  sqlite3

apt-get --yes install libssl-dev
#apt-get --yes install python-pycurl
#apt-get --yes install libcurl4-openssl-dev

apt-get --yes install libsqlite3-dev

# Remove the default nginx config
rm -f /etc/nginx/sites-enabled/default
