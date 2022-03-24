#!/usr/bin/env bash

set -o errexit

app_port=9081
working_dir=$PWD
immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
endpoint_url="http://localhost:9000"
export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"

cleanup () {
  echo 'cleanup'
  docker stop minio || printf 'ignored'
  docker rm minio || printf 'ignored'
  docker stop chillbox || printf 'ignored'
  docker rm chillbox || printf 'ignored'
  docker network rm chillboxnet || printf 'ignored'
}
trap cleanup err
cleanup

docker network create chillboxnet --driver bridge || echo 'ignore existing network'

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

# Set chillbox_url as empty string since this is local.
eval "$(jq --arg jq_immutable_bucket_name $immutable_bucket_name \
  --arg jq_artifact_bucket_name $artifact_bucket_name \
  --arg jq_endpoint_url $endpoint_url \
  --null-input '{
    immutable_bucket_name: $jq_immutable_bucket_name,
    artifact_bucket_name: $jq_artifact_bucket_name,
    endpoint_url: $jq_endpoint_url,
    chillbox_url: "",
}' | ./build-artifacts.sh | jq -r '@sh "SITES_ARTIFACT=\(.sites_artifact)"')"
echo $SITES_ARTIFACT

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
# Use the '--network host' in order to connect to the local s3 (minio) when building.
DOCKER_BUILDKIT=1 docker build --progress=plain \
  -t chillbox \
  --build-arg S3_ARTIFACT_ENDPOINT_URL="http://$(hostname -I | cut -f1 -d ' '):9000"  \
  --build-arg S3_ENDPOINT_URL="http://minio:9000" \
  --build-arg IMMUTABLE_BUCKET_NAME=$immutable_bucket_name \
  --build-arg ARTIFACT_BUCKET_NAME=$artifact_bucket_name \
  --build-arg SITES_ARTIFACT=$SITES_ARTIFACT \
  --build-arg CHILLBOX_SERVER_PORT=$app_port \
  --network host \
  --secret=id=awscredentials,src="$tmp_awscredentials" \
  --secret=id=site_secrets,src="$tmp_site_secrets" \
  .

docker run -d --tty --name chillbox \
  -e CHILLBOX_SERVER_NAME=chillbox.test \
  -e S3_ENDPOINT_URL="http://minio:9000" \
  -e ARTIFACT_BUCKET_NAME="chillboxartifact" \
  -e IMMUTABLE_BUCKET_NAME="chillboximmutable" \
  -e CHILLBOX_SERVER_PORT=$app_port \
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
