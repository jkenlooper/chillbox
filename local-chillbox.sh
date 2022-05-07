#!/usr/bin/env bash

set -o errexit

# This script depends on 'aws s3' commands to interact with the local
# chillbox-minio s3 object store. It will automatically create
# a 'local-chillbox' profile with the credentials needed for interacting with
# the local chillbox-minio s3 object store.
command -v aws > /dev/null || (echo "ERROR $0: Requires the aws command to be installed" && exit 1)

# These are only used for local development. The AWS credentials specified here
# are used for the local S3 object storage server; Minio in this case. Any other
# apps that need to interact with the local S3 should also use the below
# credentials by setting the AWS_PROFILE to 'local-chillbox'.
# WARNING: Do NOT use actual AWS credentials here!
export local_chillbox_app_key_id="local-chillbox-app-key-id"
export local_chillbox_secret_access_key="local-secret-access-key-with-readwrite-policy"

# UPKEEP due: "2022-06-15" label: "bitnami/minio image" interval: "2 months"
#docker pull bitnami/minio:2022.3.26-debian-10-r4
#docker image ls --digests bitnami/minio
# https://github.com/bitnami/bitnami-docker-minio
MINIO_IMAGE="bitnami/minio:2022.3.26-debian-10-r4@sha256:398ea232ada79b41d2d0b0b96d7d01be723c0c13904b58295302cb2908db7022"

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
MINIO_ROOT_USER=${MINIO_ROOT_USER:-'chillbox-admin'}
test "${#MINIO_ROOT_USER}" -ge 3 || (echo "Minio root user must be greater than 3 characters" && exit 1)
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-'chillllamabox'}
test "${#MINIO_ROOT_PASSWORD}" -ge 8 || (echo "Minio root password must be greater than 8 characters" && exit 1)

cleanup () {
  echo 'cleanup'
  docker stop chillbox-minio > /dev/null || echo '   ...ignored'
  docker rm chillbox-minio > /dev/null || echo '   ...ignored'
  docker stop chillbox > /dev/null || echo '   ...ignored'
  docker rm chillbox > /dev/null || echo '   ...ignored'
  docker network rm chillboxnet > /dev/null || echo '   ...ignored'
}
cleanup

docker network create chillboxnet --driver bridge || echo '   ...ignore existing network'

docker run --name chillbox-minio \
  -d \
  --tty \
  --env MINIO_ROOT_USER="$MINIO_ROOT_USER" \
  --env MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
  --env MINIO_DEFAULT_BUCKETS="${immutable_bucket_name}:public,${artifact_bucket_name}" \
  --publish 9000:9000 \
  --publish 9001:9001 \
  --network chillboxnet \
  --mount 'type=volume,src=chillbox-minio-data,dst=/data,readonly=false' \
  $MINIO_IMAGE

printf "\nWaiting for chillbox-minio container to be in running state."
while true; do
  sleep 1
  chillbox_minio_state="$(docker inspect --format '{{.State.Running}}' chillbox-minio)"
  if [ "${chillbox_minio_state}" = "true" ]; then
    printf "."
    # Try to run a minio-client command to check if the minio server is online.
    docker exec chillbox-minio mc admin info local --json | jq --exit-status '.info.mode == "online"' > /dev/null 2> /dev/null || continue
    echo -e "\nSuccess: mc admin info local"
    # Need to also check if the 'mc admin user list' command will respond
    docker exec chillbox-minio mc admin user list local 2> /dev/null || continue
    echo "Success: mc admin user list local"
    break
  else
    printf "% ..." "$(docker inspect --format '{{.State.Status}}' chillbox-minio)"
  fi
done
#wget --quiet --tries=10 --retry-connrefused --show-progress --server-response --waitretry=1 -O /dev/null http://localhost:9001
docker logs chillbox-minio
docker exec chillbox-minio mc admin user add local "${local_chillbox_app_key_id}" "${local_chillbox_secret_access_key}" || echo "   ...ignored"
docker exec chillbox-minio mc admin policy set local readwrite user="${local_chillbox_app_key_id}"

## Setup for a local shared secrets container.
tmp_cred_csv=$(mktemp)
rm_tmp_cred_csv() {
  test ! -f "$tmp_cred_csv" || rm "$tmp_cred_csv"
}
trap rm_tmp_cred_csv EXIT
docker stop --time 0 chillbox-local-shared-secrets || printf ""
docker rm  chillbox-local-shared-secrets || printf ""
docker image rm chillbox-local-shared-secrets || printf ""
# Avoid adding docker context by using stdin for the Dockerfile.
DOCKER_BUILDKIT=1 docker build -t chillbox-local-shared-secrets - < local-shared-secrets.Dockerfile
docker run -d --rm \
  --name  chillbox-local-shared-secrets \
  --mount "type=volume,src=chillbox-local-shared-secrets-var-lib,dst=/var/lib/chillbox-shared-secrets,readonly=false" \
  chillbox-local-shared-secrets
# Create a 'local-chillbox' aws profile with the chillbox-minio user. This way
# local apps can interact with the local chillbox minio s3 object store by
# setting the AWS_PROFILE to 'local-chillbox'.
cat <<HERE > "${tmp_cred_csv}"
User Name, Access Key ID, Secret Access Key
local-chillbox,${local_chillbox_app_key_id},${local_chillbox_secret_access_key}
HERE
aws configure import --csv "file://$tmp_cred_csv"

# Make this local-chillbox.credentials.csv available for other containers that
# may need to interact with the local chillbox minio s3 object store.
docker exec chillbox-local-shared-secrets mkdir -p /var/lib/chillbox-shared-secrets/chillbox-minio
docker exec chillbox-local-shared-secrets chmod -R 700 /var/lib/chillbox-shared-secrets/chillbox-minio
docker cp "${tmp_cred_csv}" chillbox-local-shared-secrets:/var/lib/chillbox-shared-secrets/chillbox-minio/local-chillbox.credentials.csv
