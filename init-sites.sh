#!/usr/bin/env bash

set -o errexit

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
endpoint_url="http://localhost:9000"
chillbox_host="http://localhost:8080"
export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"

# TODO: Temporarily using chill-box repo as the sites repo.
sites_repo="git@github.com:jkenlooper/chillbox-sites-snowflake.git"
sites_branch="main"

aws configure set default.s3.max_concurrent_requests 1
#aws configure set default.s3.max_bandwidth 1MB/s

working_dir=$PWD

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

chillbox_artifact=chillbox.$(cat VERSION).tar.gz
if [ ! -e $chillbox_artifact ]; then
  tar -c -z -f $chillbox_artifact \
    default.nginx.conf \
    nginx.conf \
    templates \
    bin \
    VERSION
fi
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp $chillbox_artifact \
  s3://${artifact_bucket_name}/chillbox/



tmp_sites_dir=$(mktemp -d)
git clone --depth 1 --single-branch --branch "$sites_branch" $sites_repo $tmp_sites_dir
cd $tmp_sites_dir

sites_commit_id=$(git rev-parse --short HEAD)

sites=$(find sites -type f -name '*.site.json')

echo $sites

upload_immutable() {
  archive_file=$1
  immutable_tmp_dir=$(mktemp -d)
  tar --directory=$immutable_tmp_dir --extract --gunzip -f $archive_file

  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp $immutable_tmp_dir/$slugname/ \
    s3://${immutable_bucket_name}/${slugname}/${version} \
    --cache-control 'public, max-age:31536000, immutable' \
    --recursive
}

upload_artifact() {
  archive_file=$1
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp $archive_file \
    s3://${artifact_bucket_name}/${slugname}/
}

for site_json in $sites; do
  cd $tmp_sites_dir
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname
  version="$(jq -r '.version' $site_json)"
  version_url="$chillbox_host/$slugname/version.txt"

  # TODO: only enable if not running local.
  if [ "1" = "0" ]; then
    curl "$version_url" --head --silent --show-error || (echo "Error when getting $version_url" && exit 1)
    deployed_version=$(curl "$version_url" --silent)

    if [ "$version" = "$deployed_version" ]; then
      echo "Versions match for $slugname site."
      continue
    fi
  fi

  immutable_path=$(aws \
    --endpoint-url "$endpoint_url" \
    s3 ls s3://${immutable_bucket_name}/${slugname}/${version} || printf '')
  artifact_path=$(aws \
    --endpoint-url "$endpoint_url" \
    s3 ls s3://${artifact_bucket_name}/${slugname}/$slugname-$version.artifact.tar.gz || printf '')

  if [ -z "$immutable_path" -a -z "$artifact_path" ]; then
    echo "
    These paths are not found in S3:
    s3://${immutable_bucket_name}/${slugname}/${version}
    s3://${artifact_bucket_name}/${slugname}/$slugname-$version.artifact.tar.gz
    Creating and uploading these now.
    "
  elif [ -z "$immutable_path" ]; then
    echo "
    Only missing immutable S3 path:
    s3://${immutable_bucket_name}/${slugname}/${version}
    "
  elif [ -z "$artifact_path" ]; then
    echo "
    Only missing artifact S3 path:
    s3://${artifact_bucket_name}/${slugname}/$slugname-$version.artifact.tar.gz
    "
  else
    echo "Immutable objects and artifact files already uploaded for $slugname $version"
    continue
  fi

  tmp_dir=$(mktemp -d)
  git_repo="$(jq -r '.git_repo' $site_json)"
  git clone --depth 1 --single-branch --branch "$version" $git_repo $tmp_dir
  cd $tmp_dir
  make

  immutable_archive_file=$tmp_dir/$slugname-$version.immutable.tar.gz
  test -f $immutable_archive_file || (echo "No file at $immutable_archive_file" && exit 1)

  artifact_file=$tmp_dir/$slugname-$version.artifact.tar.gz
  test -f $artifact_file || (echo "No file at $artifact_file" && exit 1)

  upload_immutable $immutable_archive_file
  upload_artifact $artifact_file
  # s3://${artifact_bucket_name}/${slugname}/$slugname-$version.artifact.tar.gz

done

cd $tmp_sites_dir
tmp_sites_artifact=$(mktemp)
export SITES_ARTIFACT=$(basename ${sites_repo%.git})-$sites_branch-$sites_commit_id.tar.gz
tar -c -z -f $tmp_sites_artifact sites
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp $tmp_sites_artifact  \
  s3://${artifact_bucket_name}/_sites/$SITES_ARTIFACT

echo "SITES_ARTIFACT=$SITES_ARTIFACT"

tmp_awscredentials=$(mktemp)
remove_tmp_awscredentials () {
  rm "$tmp_awscredentials"
}
trap remove_tmp_awscredentials err exit
cat << MEOW > "$tmp_awscredentials"
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
MEOW

cd $working_dir
# Use the '--network host' in order to connect to the local s3 (minio) when building.
DOCKER_BUILDKIT=1 docker build --progress=plain \
  -t chillbox \
  --build-arg S3_ARTIFACT_ENDPOINT_URL=http://$(hostname -I | cut -f1 -d ' '):9000 \
  --build-arg S3_ENDPOINT_URL=http://minio:9000 \
  --build-arg IMMUTABLE_BUCKET_NAME=$immutable_bucket_name \
  --build-arg ARTIFACT_BUCKET_NAME=$artifact_bucket_name \
  --build-arg SITES_ARTIFACT=$SITES_ARTIFACT \
  --network host \
  --secret=id=awscredentials,src="$tmp_awscredentials" \
  .

docker run -d --name chillbox --network chillboxnet -p 9081:80 chillbox

echo "
Sites running on http://localhost:9081
"
for a in {0..3}; do
  test $a -eq 0 || sleep 1
  echo "Checking if chillbox is up."
  curl --retry 3 --retry-connrefused --silent --show-error "http://localhost:9081/healthcheck/" || continue
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
  echo "http://localhost:9081/$slugname/version.txt"
  printf " Version: "
  test -z $(curl --retry 1 --retry-connrefused  --fail --show-error --no-progress-meter "http://localhost:9081/$slugname/version.txt") && echo "NO VERSION FOUND" && continue
  curl --fail --show-error --no-progress-meter "http://localhost:9081/$slugname/version.txt"
  echo "http://$slugname.test:9081"
  curl --fail --show-error --silent --head "http://$slugname.test:9081" || continue
done
cd -
