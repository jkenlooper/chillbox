#!/usr/bin/env sh

set -o errexit

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
export MINIO_DEFAULT_BUCKETS="${immutable_bucket_name}:public,${artifact_bucket_name}"

test -n "$MINIO_ROOT_USER" || (echo "No MINIO_ROOT_USER environment variable set" && exit 1)
test -n "$MINIO_ROOT_PASSWORD" || (echo "No MINIO_ROOT_PASSWORD environment variable set" && exit 1)

apk add minio minio-client minio-openrc
# Modify the /etc/conf.d/minio
rc-update add minio default
rc-service minio start

printf "\n%s\n" "Waiting for minio service to be in running state."
while true; do
    printf "."
    # Try to run a minio-client command to check if the minio service is online.
    mc admin info local --json | jq --exit-status '.info.mode == "online"' > /dev/null 2>&1 || continue
    # Need to also check if the 'mc admin user list' command will respond
    mc admin user list local > /dev/null 2>&1 || continue
    echo ""
    break
  sleep 0.1
done

# The user and policy may already exist. Ignore errors here.
mc admin user add local "${local_chillbox_app_key_id}" "${local_chillbox_secret_access_key}" 2> /dev/null || printf ""
mc admin policy set local readwrite user="${local_chillbox_app_key_id}" 2> /dev/null || printf ""
