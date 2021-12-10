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

docker stop minio || echo 'ignore minio not running'
docker rm minio || echo 'ignore minio missing container'
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
# TODO: make the $immutable_bucket_name public

./bin/upload-version.sh

sites=$(find sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname
  version="$(jq -r '.version' $site_json)"

	aws \
    --endpoint-url "$endpoint_url" \
    --output json \
    s3api list-objects-v2 \
      --bucket $immutable_bucket_name \
      --prefix $slugname/$version/ \
      --delimiter '/'
#{
#    "CommonPrefixes": [
#        {
#            "Prefix": "jengalaxyart/0.3.0-alpha.1/client-side-public/"
#        },
#        {
#            "Prefix": "jengalaxyart/0.3.0-alpha.1/design-tokens/"
#        },
#        {
#            "Prefix": "jengalaxyart/0.3.0-alpha.1/source-media/"
#        }
#    ]
#}

#TODO: convert the prefix paths to site env file (site_env_vars)
# JENGALAXYART_IMMUTABLE__DESIGN_TOKENS="jengalaxyart/0.3.0-alpha.1/design-tokens/"


done

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
