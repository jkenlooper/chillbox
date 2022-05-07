#!/usr/bin/env sh

set -o errexit

slugname="${slugname:-$1}"
version="${version:-$2}"

export slugname=${slugname}
test -n "${slugname}" || (echo "ERROR $0: slugname variable is empty" && exit 1)
echo "INFO $0: Using slugname '${slugname}'"

export version=${version}
test -n "${version}" || (echo "ERROR $0: version variable is empty" && exit 1)
echo "INFO $0: Using version '${version}'"

export S3_ARTIFACT_ENDPOINT_URL=${S3_ARTIFACT_ENDPOINT_URL}
test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

export ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

export IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
test -n "${IMMUTABLE_BUCKET_NAME}" || (echo "ERROR $0: IMMUTABLE_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using IMMUTABLE_BUCKET_NAME '${IMMUTABLE_BUCKET_NAME}'"

test -n "$AWS_PROFILE" || (echo "ERROR $0: No AWS_PROFILE set." && exit 1)

echo "INFO $0: Checking and extracting files to immutable bucket for: ${slugname} ${version}"

immutable_version_file_exists=$(aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 ls \
  "s3://${IMMUTABLE_BUCKET_NAME}/$slugname/$version/version.txt" || printf '')
if [ -n "$immutable_version_file_exists" ]; then
  echo "INFO $0: Immutable version file already exists: s3://${IMMUTABLE_BUCKET_NAME}/$slugname/$version/version.txt"
  echo "INFO $0: Skipping upload to immutable bucket for $slugname $version."
  exit 0
fi

immutable_archive_file="${slugname}-${version}.immutable.tar.gz"
tmp_artifact=$(mktemp)

artifact_exists=$(aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 ls \
  "s3://${ARTIFACT_BUCKET_NAME}/$slugname/artifacts/$immutable_archive_file" || printf '')
if [ -z "$artifact_exists" ]; then
  echo "ERROR $0: Immutable archive file doesn't exist: s3://${ARTIFACT_BUCKET_NAME}/$slugname/artifacts/$immutable_archive_file"
  exit 1
else
  aws \
    --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp \
    "s3://${ARTIFACT_BUCKET_NAME}/$slugname/artifacts/$immutable_archive_file"  \
    "$tmp_artifact"
fi

# Extract the immutable archive file to the immutable bucket.
immutable_tmp_dir="$(mktemp -d)"
tar x -z -f "$tmp_artifact" -C "$immutable_tmp_dir"

# Create a version.txt file in the immutable directory so it can be used for
# version verification.
echo "${version}" > "$immutable_tmp_dir/$slugname/version.txt"

aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  "$immutable_tmp_dir/$slugname/" \
  "s3://${IMMUTABLE_BUCKET_NAME}/${slugname}/${version}" \
  --cache-control 'public, max-age:31536000, immutable' \
  --acl 'public-read' \
  --recursive
