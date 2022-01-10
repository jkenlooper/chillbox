#!/usr/bin/env bash

# Move the minio specific bits into it's own script.
# The local environment should set the tfvars to not create bucket resources on
# linode and will use the local minio server.

# Example of getting terraform variables.
# echo "var.chillbox_artifact" | terraform console | xargs

set -o errexit

# Need to use a log file for stdout since the stdout will be parsed as JSON by
# terraform external data source.
BUILD_ARTIFACTS_LOG_FILE=build-artifacts.sh.log
echo $(date) > $BUILD_ARTIFACTS_LOG_FILE

test -n "$AWS_ACCESS_KEY_ID" || (echo "No AWS_ACCESS_KEY_ID set." && exit 1)
test -n "$AWS_SECRET_ACCESS_KEY" || (echo "No AWS_SECRET_ACCESS_KEY set." && exit 1)

# Extract and set shell variables from JSON input
eval "$(jq -r '@sh "
  immutable_bucket_name=\(.immutable_bucket_name)
  artifact_bucket_name=\(.artifact_bucket_name)
  endpoint_url=\(.endpoint_url)
  chillbox_url=\(.chillbox_url)
  "')"

sites_repo="git@github.com:jkenlooper/chillbox-sites-snowflake.git"
sites_branch="main"

aws configure set default.s3.max_concurrent_requests 1
#aws configure set default.s3.max_bandwidth 1MB/s

working_dir=$PWD


tmp_sites_dir=$(mktemp -d)
git clone --depth 1 --single-branch --branch "$sites_branch" $sites_repo $tmp_sites_dir
cd $tmp_sites_dir

sites_commit_id=$(git rev-parse --short HEAD)
SITES_ARTIFACT=$(basename ${sites_repo%.git})-$sites_branch-$sites_commit_id.tar.gz

# Check if sites artifact exists in s3 bucket and exit early if so.
sites_artifact_exists=$(aws \
  --endpoint-url "$endpoint_url" \
  s3 ls \
  s3://${artifact_bucket_name}/_sites/$SITES_ARTIFACT || printf '')
if [ -n "$sites_artifact_exists" ]; then
  jq --null-input --arg sites_artifact "$SITES_ARTIFACT" '{sites_artifact:$sites_artifact}'
  echo "No changes to existing site artifact: $SITES_ARTIFACT" >> $BUILD_ARTIFACTS_LOG_FILE
  exit 0
fi

cd $working_dir
chillbox_artifact=chillbox.$(cat VERSION).tar.gz
if [ ! -e $chillbox_artifact ]; then
  tar -c -z -f $chillbox_artifact \
    default.nginx.conf \
    nginx.conf \
    templates \
    bin \
    VERSION
fi
#echo "endpoint_url = $endpoint_url"
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp $chillbox_artifact \
  s3://${artifact_bucket_name}/chillbox/ >> $BUILD_ARTIFACTS_LOG_FILE

cd $tmp_sites_dir

sites=$(find sites -type f -name '*.site.json')

echo $sites >> $BUILD_ARTIFACTS_LOG_FILE

upload_immutable() {
  archive_file=$1
  immutable_tmp_dir=$(mktemp -d)
  tar --directory=$immutable_tmp_dir --extract --gunzip -f $archive_file

  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp $immutable_tmp_dir/$slugname/ \
    s3://${immutable_bucket_name}/${slugname}/${version} \
    --cache-control 'public, max-age:31536000, immutable' \
    --recursive >> $BUILD_ARTIFACTS_LOG_FILE
}

upload_artifact() {
  archive_file=$1
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp $archive_file \
    s3://${artifact_bucket_name}/${slugname}/ >> $BUILD_ARTIFACTS_LOG_FILE
}

for site_json in $sites; do
  cd $tmp_sites_dir
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname >> $BUILD_ARTIFACTS_LOG_FILE
  version="$(jq -r '.version' $site_json)"

  # Only enable if not running local.
  if [ -n "$chillbox_url" ]; then
    version_url="${chillbox_url}$slugname/version.txt"
    curl "$version_url" --head --silent --show-error || (echo "Error when getting $version_url" && exit 1)
    deployed_version=$(curl "$version_url" --silent)

    if [ "$version" = "$deployed_version" ]; then
      echo "Versions match for $slugname site." >> $BUILD_ARTIFACTS_LOG_FILE
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
    " >> $BUILD_ARTIFACTS_LOG_FILE
  elif [ -z "$immutable_path" ]; then
    echo "
    Only missing immutable S3 path:
    s3://${immutable_bucket_name}/${slugname}/${version}
    " >> $BUILD_ARTIFACTS_LOG_FILE
  elif [ -z "$artifact_path" ]; then
    echo "
    Only missing artifact S3 path:
    s3://${artifact_bucket_name}/${slugname}/$slugname-$version.artifact.tar.gz
    " >> $BUILD_ARTIFACTS_LOG_FILE
  else
    echo "Immutable objects and artifact files already uploaded for $slugname $version" >> $BUILD_ARTIFACTS_LOG_FILE
    continue
  fi

  tmp_dir=$(mktemp -d)
  git_repo="$(jq -r '.git_repo' $site_json)"
  git clone --depth 1 --single-branch --branch "$version" --recurse-submodules $git_repo $tmp_dir >> $BUILD_ARTIFACTS_LOG_FILE
  cd $tmp_dir
  make >> $BUILD_ARTIFACTS_LOG_FILE

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
tar -c -z -f $tmp_sites_artifact sites >> $BUILD_ARTIFACTS_LOG_FILE
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp $tmp_sites_artifact  \
  s3://${artifact_bucket_name}/_sites/$SITES_ARTIFACT >> $BUILD_ARTIFACTS_LOG_FILE

echo "SITES_ARTIFACT=$SITES_ARTIFACT" >> $BUILD_ARTIFACTS_LOG_FILE
jq --null-input --arg sites_artifact "$SITES_ARTIFACT" '{sites_artifact:$sites_artifact}'
