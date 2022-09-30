#!/usr/bin/env sh

set -o errexit

# AWS_PROFILE=""
# IMMUTABLE_BUCKET_NAME=""
# IMMUTABLE_BUCKET_DOMAIN_NAME=""
# ARTIFACT_BUCKET_NAME=""
# S3_ENDPOINT_URL=""
# S3_ARTIFACT_ENDPOINT_URL=""
# CHILLBOX_ARTIFACT=""
# CHILLBOX_SERVER_NAME=""
# CHILLBOX_SERVER_PORT=""
# SITES_ARTIFACT=""
# TECH_EMAIL=""
# shellcheck disable=SC1091
. /home/dev/.env

export INTERACTIVE="yes"

mkdir -p /usr/local/src/
cd /usr/local/src/

# TODO how to remove the version.txt so the update can happen and get new
# secrets?
/etc/chillbox/bin/site-init.sh

/etc/chillbox/bin/reload-templates.sh
nginx -t && nginx -s reload
