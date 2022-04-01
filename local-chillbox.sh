#!/usr/bin/env bash

set -o errexit

# These are only used for local development. The AWS credentials specified here
# are used for the local S3 object storage server; Minio in this case. Any other
# apps that need to interact with the local S3 should also use the below
# credentials.
# WARNING: Do NOT use actual AWS credentials here!
export AWS_ACCESS_KEY_ID="local-chillbox-app-key-id"
export AWS_SECRET_ACCESS_KEY="local-secret-access-key-with-readwrite-policy"

#docker pull bitnami/minio:2022.3.26-debian-10-r4
#docker image ls --digests bitnami/minio
# https://github.com/bitnami/bitnami-docker-minio
MINIO_IMAGE="bitnami/minio:2022.3.26-debian-10-r4@sha256:398ea232ada79b41d2d0b0b96d7d01be723c0c13904b58295302cb2908db7022"

# Allow setting defaults for local development
LOCAL_ENV_CONFIG=${1:-".local-env"}
test -f "${LOCAL_ENV_CONFIG}" && source "${LOCAL_ENV_CONFIG}"

# The .local-env file (or the file that was the first arg) would typically set these variables.
sites_git_repo=${sites_git_repo:-"git@github.com:jkenlooper/chillbox-sites-example.git"}
sites_git_branch=${sites_git_branch:-"main"}

app_port=9081
working_dir=$PWD
tech_email="local@example.com"
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
docker exec chillbox-minio mc admin user add local "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}" || echo "   ...ignored"
docker exec chillbox-minio mc admin policy set local readwrite user="${AWS_ACCESS_KEY_ID}"

# Set chillbox_url as empty string since this is local.
eval "$(jq --arg jq_immutable_bucket_name $immutable_bucket_name \
  --arg jq_artifact_bucket_name $artifact_bucket_name \
  --arg jq_endpoint_url $endpoint_url \
  --arg jq_sites_git_repo $sites_git_repo \
  --arg jq_sites_git_branch $sites_git_branch \
  --null-input '{
    sites_git_repo: $jq_sites_git_repo,
    sites_git_branch: $jq_sites_git_branch,
    immutable_bucket_name: $jq_immutable_bucket_name,
    artifact_bucket_name: $jq_artifact_bucket_name,
    endpoint_url: $jq_endpoint_url,
    chillbox_url: "",
}' | ./build-artifacts.sh | jq -r '@sh "SITES_ARTIFACT=\(.sites_artifact)"')"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $0: The SITES_ARTIFACT variable is empty." && exit 1)

echo "SITES_ARTIFACT=$SITES_ARTIFACT"

tmp_awscredentials=$(mktemp)
remove_tmp_awscredentials () {
  rm "$tmp_awscredentials"
}
trap remove_tmp_awscredentials exit
cat << MEOW > "$tmp_awscredentials"
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
MEOW

tmp_site_secrets=$(mktemp)
remove_tmp_site_secrets () {
  rm "${tmp_site_secrets}"
}
trap remove_tmp_site_secrets exit
tar c -z -f "${tmp_site_secrets}" local-secrets

cd $working_dir
# Use the '--network host' in order to connect to the local s3 (chillbox-minio) when building.
DOCKER_BUILDKIT=1 docker build --progress=plain \
  -t chillbox \
  --build-arg S3_ARTIFACT_ENDPOINT_URL="http://$(hostname -I | cut -f1 -d ' '):9000"  \
  --build-arg S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  --build-arg IMMUTABLE_BUCKET_NAME=$immutable_bucket_name \
  --build-arg ARTIFACT_BUCKET_NAME=$artifact_bucket_name \
  --build-arg SITES_ARTIFACT=$SITES_ARTIFACT \
  --build-arg CHILLBOX_SERVER_PORT=80 \
  --build-arg TECH_EMAIL="${tech_email}" \
  --build-arg LETS_ENCRYPT_SERVER="letsencrypt_test" \
  --network host \
  --secret=id=awscredentials,src="$tmp_awscredentials" \
  --secret=id=site_secrets,src="$tmp_site_secrets" \
  .

docker run -d --tty --name chillbox \
  -e CHILLBOX_SERVER_NAME=chillbox.test \
  -e S3_ENDPOINT_URL="http://chillbox-minio:9000" \
  -e ARTIFACT_BUCKET_NAME="chillboxartifact" \
  -e IMMUTABLE_BUCKET_NAME="chillboximmutable" \
  -e CHILLBOX_SERVER_PORT=80 \
  --network chillboxnet \
  -p $app_port:80 chillbox

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
