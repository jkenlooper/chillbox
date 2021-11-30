#!/bin/env sh

set -v

set -o errexit

endpoint_url="http://192.168.120.226:38714"
immutable_bucket_name="chum"

aws configure set default.s3.max_concurrent_requests 1
#aws configure set default.s3.max_bandwidth 1MB/s

sites=$(find sites -type f -name '*.site.json')

echo $sites

upload_immutable() {
  archive_file=$1
  echo "u i $slugname"
  exit 0
  immutable_tmp_dir=$(mktemp -d)
  tar --directory=$immutable_tmp_dir --extract --gunzip -f $archive_file

  # Uses AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp $immutable_tmp_dir/$slugname/ \
    s3://${immutable_bucket_name}/${slugname}/${version} \
    --dryrun \
    --cache-control 'immutable, max-age=1234' \
    --metadata '?' \
    --recursive
}

for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname
  version="$(jq -r '.version' $site_json)"
  version_url="http://chillbox.test/$slugname/version/"

  if [ "1" = "0" ]; then
    curl "$version_url" --head --silent --show-error || (echo "No $slugname version $version found at $version_url" && exit 1)
    deployed_version=$(curl "$version_url" --silent)

    if [ "$version" = "$deployed_version" ]; then
      echo "Versions match for $slugname site."
      continue
    fi
  fi

  tmp_dir=$(mktemp -d)
  git_repo="$(jq -r '.git_repo' $site_json)"
  git clone --depth 1 --single-branch --branch "$version" $git_repo $tmp_dir
  cd $tmp_dir
  make
  immutable_archive_file=$tmp_dir/$slugname-$version.immutable.tar.gz
  test -f $immutable_archive_file || (echo "No file at $immutable_archive_file" && exit 1)
  upload_immutable $immutable_archive_file




done

