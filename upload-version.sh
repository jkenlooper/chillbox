#!/usr/bin/env sh

set -o errexit

# TODO: Temporarily using chill-box repo as the sites repo.
sites_repo="git@github.com:jkenlooper/chill-box.git"
sites_branch="main"

chillbox_host="http://localhost:8080"
endpoint_url="http://localhost:9000"
immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"

aws configure set default.s3.max_concurrent_requests 1
#aws configure set default.s3.max_bandwidth 1MB/s

tmp_sites_dir=$(mktemp -d)
git clone --depth 1 --single-branch --branch "$sites_branch" $sites_repo $tmp_sites_dir
cd $tmp_sites_dir

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
sites_artifact=$(mktemp)
tar -c -z -f $sites_artifact sites
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp $sites_artifact  \
  s3://${artifact_bucket_name}/_sites/$(basename ${sites_repo%.git})-$sites_branch.tar.gz
