#!/usr/bin/env sh

set -o errexit

apk add minio minio-client minio-openrc
# Modify the /etc/conf.d/minio
rc-update add minio default
rc-service minio start
