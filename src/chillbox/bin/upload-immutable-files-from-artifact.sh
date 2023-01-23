#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

SLUGNAME="${SLUGNAME:-$1}"
VERSION="${VERSION:-$2}"

test -n "${SLUGNAME}" || (echo "ERROR $script_name: SLUGNAME variable is empty" && exit 1)
echo "INFO $script_name: Using slugname '${SLUGNAME}'"

test -n "${VERSION}" || (echo "ERROR $script_name: VERSION variable is empty" && exit 1)
echo "INFO $script_name: Using version '${VERSION}'"

test -n "${S3_ENDPOINT_URL}" || (echo "ERROR $script_name: S3_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $script_name: Using S3_ENDPOINT_URL '${S3_ENDPOINT_URL}'"

test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $script_name: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

test -n "${IMMUTABLE_BUCKET_NAME}" || (echo "ERROR $script_name: IMMUTABLE_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using IMMUTABLE_BUCKET_NAME '${IMMUTABLE_BUCKET_NAME}'"

test -n "$AWS_PROFILE" || (echo "ERROR $script_name: No AWS_PROFILE set." && exit 1)

echo "INFO $script_name: Checking and extracting files to immutable bucket for: ${SLUGNAME} ${VERSION}"

# TODO the s5cmd ls will show a 'ERROR ...' string. Should these be hidden?
immutable_version_file_exists=$(s5cmd ls \
  "s3://${IMMUTABLE_BUCKET_NAME}/$SLUGNAME/versions/$VERSION/version.txt" || printf '')
if [ -n "$immutable_version_file_exists" ]; then
  echo "INFO $script_name: Immutable version file already exists: s3://${IMMUTABLE_BUCKET_NAME}/$SLUGNAME/versions/$VERSION/version.txt"
  echo "INFO $script_name: Skipping upload to immutable bucket for $SLUGNAME $VERSION."
  exit 0
fi

immutable_archive_file="${SLUGNAME}-${VERSION}.immutable.tar.gz"
tmp_artifact=$(mktemp)

artifact_exists=$(s5cmd ls \
  "s3://${ARTIFACT_BUCKET_NAME}/$SLUGNAME/artifacts/$immutable_archive_file" || printf '')
if [ -z "$artifact_exists" ]; then
  echo "ERROR $script_name: Immutable archive file doesn't exist: s3://${ARTIFACT_BUCKET_NAME}/$SLUGNAME/artifacts/$immutable_archive_file"
  exit 1
else
  s5cmd cp \
    "s3://${ARTIFACT_BUCKET_NAME}/$SLUGNAME/artifacts/$immutable_archive_file"  \
    "$tmp_artifact"
fi

# Extract the immutable archive file to the immutable bucket.
immutable_tmp_dir="$(mktemp -d)"
tar x -z -f "$tmp_artifact" -C "$immutable_tmp_dir"

# Create a version.txt file in the immutable directory so it can be used for
# version verification.
printf "%s" "${VERSION}" > "$immutable_tmp_dir/$SLUGNAME/version.txt"
s5cmd cp \
  --cache-control 'public, max-age:31536000, immutable' \
  --acl 'public-read' \
  "$immutable_tmp_dir/$SLUGNAME/version.txt" \
  "s3://${IMMUTABLE_BUCKET_NAME}/${SLUGNAME}/versions/${VERSION}/version.txt"

s5cmd cp \
  --cache-control 'public, max-age:31536000, immutable' \
  --acl 'public-read' \
  "$immutable_tmp_dir/$SLUGNAME/*" \
  "s3://${IMMUTABLE_BUCKET_NAME}/${SLUGNAME}/immutable/"
