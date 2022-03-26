#!/usr/bin/env sh

set -o errexit

mkdir -p /etc/chillbox
cat <<'ENV_NAMES' > /etc/chillbox/env_names
$CHILLBOX_SERVER_NAME
$CHILLBOX_SERVER_PORT
$S3_ENDPOINT_URL
$IMMUTABLE_BUCKET_NAME
$ARTIFACT_BUCKET_NAME
$slugname
$version
$server_name
$server_port
ENV_NAMES
