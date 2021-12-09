#!/usr/bin/env bash

set -o errexit

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
endpoint_url="http://localhost:9000"
AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
export AWS_SECRET_ACCESS_KEY

cleanup () {
  echo 'cleanup'
  docker stop minio
  docker rm minio
  docker network rm chillboxnet
}
trap cleanup err exit

docker network create chillboxnet --driver bridge || echo 'ignore existing network'

mkdir -p minio-data
docker run --name minio \
  -d \
  --env MINIO_ACCESS_KEY="$AWS_ACCESS_KEY_ID" \
  --env MINIO_SECRET_KEY="$AWS_SECRET_ACCESS_KEY" \
  --publish 9000:9000 \
  --publish 9001:9001 \
  --network chillboxnet \
  --mount 'type=volume,src=chillboxdata,dst=/data,readonly=false' \
  bitnami/minio:latest



for bucketname in $immutable_bucket_name $artifact_bucket_name; do
  aws \
    --endpoint-url "$endpoint_url" \
    s3 mb s3://$bucketname || echo "Ignoring error if bucket already exists."
done

./bin/upload-version.sh

tmp_awscredentials=$(mktemp)
remove_tmp_awscredentials () {
  rm "$tmp_awscredentials"
}
trap remove_tmp_awscredentials err exit
cat << MEOW > "$tmp_awscredentials"
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
MEOW

# Use the '--network host' in order to connect to the local s3 (minio) when building.
DOCKER_BUILDKIT=1 docker build --progress=plain \
  -t chillbox \
  --build-arg S3_ENDPOINT_URL=http://$(hostname -I | cut -f1 -d ' '):9000 \
  --build-arg IMMUTABLE_BUCKET_NAME=$immutable_bucket_name \
  --build-arg ARTIFACT_BUCKET_NAME=$artifact_bucket_name \
  --network host \
  --secret=id=awscredentials,src="$tmp_awscredentials" \
  .

# On remote chillbox host (only read access to S3)
# - Download artifact tar.gz from S3
# - Expand to new directory for the version
# - chill init, load yaml
# - add and enable, start the systemd service for new version
# - stage the new version by updating NGINX environment variables
# - run integration tests on staged version
# - promote the staged version to production by updating NGINX environment variables
# - remove old version
# - write version to /srv/chillbox/$slugname/version.txt
