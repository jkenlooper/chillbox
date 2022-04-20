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

# Allow setting defaults for local development
LOCAL_ENV_CONFIG=${1:-".local-env"}
test -f "${LOCAL_ENV_CONFIG}" && source "${LOCAL_ENV_CONFIG}"

# The .local-env file (or the file that was the first arg) would typically set these variables.
SITES_GIT_REPO=${SITES_GIT_REPO:-"git@github.com:jkenlooper/chillbox-sites-example.git"}
SITES_GIT_BRANCH=${SITES_GIT_BRANCH:-"main"}

app_port=9081
working_dir=$PWD
immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
endpoint_url="http://localhost:9000"
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
    printf "$(docker inspect --format '{{.State.Status}}' chillbox-minio) ..."
  fi
done
#wget --quiet --tries=10 --retry-connrefused --show-progress --server-response --waitretry=1 -O /dev/null http://localhost:9001
docker logs chillbox-minio
docker exec chillbox-minio mc admin user add local "${local_chillbox_app_key_id}" "${local_chillbox_secret_access_key}" || echo "   ...ignored"
docker exec chillbox-minio mc admin policy set local readwrite user="${local_chillbox_app_key_id}"

## Setup for a local shared secrets container.
tmp_cred_csv=$(mktemp)
rm_tmp_cred_csv() {
  test -f "$tmp_cred_csv" && rm "$tmp_cred_csv"
}
trap rm_tmp_cred_csv EXIT
docker stop --time 0 chillbox-local-shared-secrets || printf ""
docker rm  chillbox-local-shared-secrets || printf ""
# Avoid adding docker context by using stdin for the Dockerfile.
cat local-shared-secrets.Dockerfile | DOCKER_BUILDKIT=1 docker build -t chillbox-local-shared-secrets -
docker run -d --rm \
  --name  chillbox-local-shared-secrets \
  --mount "type=volume,src=chillbox-local-shared-secrets-var-lib,dst=/var/lib/chillbox-shared-secrets,readonly=false" \
  chillbox-local-shared-secrets
# Create a 'local-chillbox' aws profile with the chillbox-minio user. This way
# local apps can interact with the local chillbox minio s3 object store by
# setting the AWS_PROFILE to 'local-chillbox'.
cat <<HERE > $tmp_cred_csv
User Name, Access Key ID, Secret Access Key
local-chillbox,${local_chillbox_app_key_id},${local_chillbox_secret_access_key}
HERE
aws configure import --csv "file://$tmp_cred_csv"

# Make this local-chillbox.credentials.csv available for other containers that
# may need to interact with the local chillbox minio s3 object store.
docker exec chillbox-local-shared-secrets mkdir -p /var/lib/chillbox-shared-secrets/chillbox-minio
docker exec chillbox-local-shared-secrets chmod -R 700 /var/lib/chillbox-shared-secrets/chillbox-minio
docker cp $tmp_cred_csv chillbox-local-shared-secrets:/var/lib/chillbox-shared-secrets/chillbox-minio/local-chillbox.credentials.csv
# Export the AWS_PROFILE env var so the rest of the commands in upload-artifacts
# will use the local-chillbox profile when running the aws commands.
export AWS_PROFILE="local-chillbox"
rm_tmp_cred_csv

## Build the artifacts
eval "$(jq \
  --arg jq_sites_git_repo "$SITES_GIT_REPO" \
  --arg jq_sites_git_branch "$SITES_GIT_BRANCH" \
  --null-input '{
    sites_git_repo: $jq_sites_git_repo,
    sites_git_branch: $jq_sites_git_branch,
}' | ./build-artifacts.sh | jq -r '@sh "
    SITES_ARTIFACT=\(.sites_artifact)
    CHILLBOX_ARTIFACT=\(.chillbox_artifact)
    SITES_MANIFEST=\(.sites_manifest)
    "')"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $0: The SITES_ARTIFACT variable is empty." && exit 1)
test -n "${CHILLBOX_ARTIFACT}" || (echo "ERROR $0: The CHILLBOX_ARTIFACT variable is empty." && exit 1)
test -n "${SITES_MANIFEST}" || (echo "ERROR $0: The SITES_MANIFEST variable is empty." && exit 1)

# TODO Create a local gpg key and upload the public key to the artifacts bucket.
# Prompt to continue so any local secret files can be manually encrypted and uploaded to the artifacts bucket?

## Upload the artifacts
jq \
  --arg jq_immutable_bucket_name "$immutable_bucket_name" \
  --arg jq_artifact_bucket_name "$artifact_bucket_name" \
  --arg jq_endpoint_url "$endpoint_url" \
  --arg jq_sites_artifact "$SITES_ARTIFACT" \
  --arg jq_chillbox_artifact "$CHILLBOX_ARTIFACT" \
  --arg jq_sites_manifest "$SITES_MANIFEST" \
  --null-input '{
    sites_artifact: $jq_sites_artifact,
    chillbox_artifact: $jq_chillbox_artifact,
    sites_manifest: $jq_sites_manifest,
    immutable_bucket_name: $jq_immutable_bucket_name,
    artifact_bucket_name: $jq_artifact_bucket_name,
    endpoint_url: $jq_endpoint_url,
}' | ./upload-artifacts.sh

cd $working_dir
# Use the '--network host' in order to connect to the local s3 (chillbox-minio) when building.
  #--build-arg S3_ARTIFACT_ENDPOINT_URL="http://$(hostname -I | cut -f1 -d ' '):9000"  \
  #--build-arg SITES_ARTIFACT=$SITES_ARTIFACT \
  #--build-arg LETS_ENCRYPT_SERVER="letsencrypt_test" \
  #--build-arg TECH_EMAIL="${tech_email}" \
  #--build-arg S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  #--build-arg IMMUTABLE_BUCKET_NAME="$immutable_bucket_name" \
  #--build-arg ARTIFACT_BUCKET_NAME="$artifact_bucket_name" \
  #--build-arg CHILLBOX_SERVER_PORT=80 \
DOCKER_BUILDKIT=1 docker build --progress=plain \
  -t chillbox \
  --network host \
  .

  #-e CHILLBOX_SERVER_PORT=80 \
docker run -d --tty --name chillbox \
  -e CHILLBOX_SERVER_NAME=chillbox.test \
  -e S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e S3_ARTIFACT_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e ARTIFACT_BUCKET_NAME="$artifact_bucket_name" \
  -e IMMUTABLE_BUCKET_NAME="$immutable_bucket_name" \
  -e SITES_ARTIFACT=$SITES_ARTIFACT \
  --mount "type=volume,src=chillbox-local-shared-secrets-var-lib,dst=/var/lib/chillbox-shared-secrets,readonly=false" \
  --network chillboxnet \
  -p $app_port:80 chillbox

printf "\nWaiting for chillbox container to be in running state."
while true; do
  chillbox_state="$(docker inspect --format '{{.State.Running}}' chillbox)"
  if [ "${chillbox_state}" = "true" ]; then
    break
  else
    printf "$(docker inspect --format '{{.State.Status}}' chillbox) ..."
  fi
  sleep 1
done

docker exec -i --tty \
  -e CHILLBOX_SERVER_NAME=chillbox.test \
  -e S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e S3_ARTIFACT_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e ARTIFACT_BUCKET_NAME="$artifact_bucket_name" \
  -e IMMUTABLE_BUCKET_NAME="$immutable_bucket_name" \
  -e SITES_ARTIFACT=$SITES_ARTIFACT \
  chillbox /usr/local/bin/chillbox-dev-nginx.sh

# Reload chillbox container to start the services
docker stop chillbox
docker start chillbox

echo "
Sites running on http://chillbox.test:$app_port
"
for a in {0..3}; do
  test $a -eq 0 || sleep 1
  echo "Checking if chillbox is up."
  curl --retry 3 --retry-connrefused --silent --show-error "http://chillbox.test:$app_port/healthcheck/" || continue
  break
done
tmp_sites_dir=$(mktemp -d)
docker cp chillbox:/etc/chillbox/sites $tmp_sites_dir/sites
cd $tmp_sites_dir
sites=$(find sites -type f -name '*.site.json')
for site_json in $sites; do
  echo ""
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname
  echo "http://chillbox.test:$app_port/$slugname/version.txt"
  printf " Version: "
  test -z $(curl --retry 1 --retry-connrefused  --fail --show-error --no-progress-meter "http://chillbox.test:$app_port/$slugname/version.txt") && echo "NO VERSION FOUND" && continue
  curl --fail --show-error --no-progress-meter "http://chillbox.test:$app_port/$slugname/version.txt"
  echo "http://$slugname.test:$app_port"
  curl --fail --show-error --silent --head "http://$slugname.test:$app_port" || continue
done
cd -
rm -rf "$tmp_sites_dir"

# Drop into the container to continue any other tasks as needed.
docker exec -i --tty \
  -e CHILLBOX_SERVER_NAME=chillbox.test \
  -e S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e S3_ARTIFACT_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e ARTIFACT_BUCKET_NAME="$artifact_bucket_name" \
  -e IMMUTABLE_BUCKET_NAME="$immutable_bucket_name" \
  -e SITES_ARTIFACT=$SITES_ARTIFACT \
  chillbox sh
