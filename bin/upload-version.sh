#!/usr/bin/env sh

set -o errexit

chillbox_host="http://localhost:38713"
endpoint_url="http://localhost:38714"
immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
export AWS_SECRET_ACCESS_KEY

aws configure set default.s3.max_concurrent_requests 1
#aws configure set default.s3.max_bandwidth 1MB/s

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
    --cache-control 'immutable, max-age=1234' \
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
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname
  version="$(jq -r '.version' $site_json)"
  version_url="$chillbox_host/$slugname/version.txt"

  if [ "1" = "1" ]; then
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

done

