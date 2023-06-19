#!/usr/bin/env sh

set -o errexit

# TODO: ntp should be setup elsewhere.
setup-ntp

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
export MINIO_DEFAULT_BUCKETS="${immutable_bucket_name}:public,${artifact_bucket_name}"

test -n "$MINIO_ROOT_USER" || (echo "No MINIO_ROOT_USER environment variable set" && exit 1)
test -n "$MINIO_ROOT_PASSWORD" || (echo "No MINIO_ROOT_PASSWORD environment variable set" && exit 1)
test -n "$ACCESS_KEY_ID" || (echo "No ACCESS_KEY_ID environment variable set" && exit 1)
test -n "$SECRET_ACCESS_KEY" || (echo "No SECRET_ACCESS_KEY environment variable set" && exit 1)

apk add minio minio-client minio-openrc jq
# Modify the /etc/conf.d/minio
rc-update add minio default
rc-service minio start

# UPKEEP due: "2023-12-19" label: "Minio admin client release" interval: "+6 months"
# https://dl.min.io/client/mc/release/linux-amd64/archive/
# minio -v
minio_admin_client_release="mc.RELEASE.2023-03-23T20-03-04Z"
wget -O /usr/local/bin/mc \
  "https://dl.min.io/client/mc/release/linux-amd64/archive/$minio_admin_client_release"
chmod +x /usr/local/bin/mc

mc config host add local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

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
mc admin user add local "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY" 2> /dev/null || printf ""
mc admin policy attach local readwrite --user "$ACCESS_KEY_ID" 2> /dev/null || printf ""

mc mb --ignore-existing "local/$immutable_bucket_name"
mc anonymous set download "local/$immutable_bucket_name"
mc mb --ignore-existing "local/$artifact_bucket_name"
