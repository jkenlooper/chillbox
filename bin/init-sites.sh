#!/usr/bin/env sh

set -o errexit

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
export AWS_SECRET_ACCESS_KEY


#docker network create chillboxnet --driver bridge

mkdir -p minio-data
docker run --name minio \
  -it --rm \
  --env MINIO_ACCESS_KEY="$AWS_ACCESS_KEY_ID" \
  --env MINIO_SECRET_KEY="$AWS_SECRET_ACCESS_KEY" \
  --publish 0.0.0.0:9000:9000 \
  --publish 0.0.0.0:9001:9001 \
  bitnami/minio:latest

#  --network chillboxnet \
#  --volume $(pwd)/minio-data:/data \

exit 0

for bucketname in chillboximmutable chillboxartifact; do
  docker run --rm \
    --env MINIO_SERVER_HOST="minio" \
    --env MINIO_SERVER_ACCESS_KEY="$AWS_ACCESS_KEY_ID" \
    --env MINIO_SERVER_SECRET_KEY="$AWS_SECRET_ACCESS_KEY" \
    --network chillboxnet \
    bitnami/minio-client \
    mb --ignore-existing minio/$bucketname
done

./bin/upload-version.sh

tmp_awscredentials=$(mktemp)
cat << MEOW > "$tmp_awscredentials"
export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
MEOW

DOCKER_BUILDKIT=1 docker build --progress=plain \
  -t chillbox \
  --secret=id=awscredentials,src="$tmp_awscredentials" \
  .
rm "$tmp_awscredentials"


docker stop minio
docker rm minio
docker network rm chillboxnet

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
