#!/usr/bin/env sh

set -o errexit

SLUGNAME="${SLUGNAME:-$1}"
VERSION="${VERSION:-$2}"

# TODO Need to export so they can be used in a subshell $(aws ...) ?
# export SLUGNAME=${SLUGNAME}
test -n "${SLUGNAME}" || (echo "ERROR $0: SLUGNAME variable is empty" && exit 1)
echo "INFO $0: Using slugname '${SLUGNAME}'"

# export VERSION=${VERSION}
test -n "${VERSION}" || (echo "ERROR $0: VERSION variable is empty" && exit 1)
echo "INFO $0: Using version '${VERSION}'"

# export S3_ARTIFACT_ENDPOINT_URL=${S3_ARTIFACT_ENDPOINT_URL}
test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

# export ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

# export IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
test -n "${IMMUTABLE_BUCKET_NAME}" || (echo "ERROR $0: IMMUTABLE_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using IMMUTABLE_BUCKET_NAME '${IMMUTABLE_BUCKET_NAME}'"

test -n "$AWS_PROFILE" || (echo "ERROR $0: No AWS_PROFILE set." && exit 1)

echo "INFO $0: Checking and extracting files to immutable bucket for: ${SLUGNAME} ${VERSION}"

immutable_version_file_exists=$(aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 ls \
  "s3://${IMMUTABLE_BUCKET_NAME}/$SLUGNAME/versions/$VERSION/version.txt" || printf '')
if [ -n "$immutable_version_file_exists" ]; then
  echo "INFO $0: Immutable version file already exists: s3://${IMMUTABLE_BUCKET_NAME}/$SLUGNAME/versions/$VERSION/version.txt"
  echo "INFO $0: Skipping upload to immutable bucket for $SLUGNAME $VERSION."
  exit 0
fi

immutable_archive_file="${SLUGNAME}-${VERSION}.immutable.tar.gz"
tmp_artifact=$(mktemp)

artifact_exists=$(aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 ls \
  "s3://${ARTIFACT_BUCKET_NAME}/$SLUGNAME/artifacts/$immutable_archive_file" || printf '')
if [ -z "$artifact_exists" ]; then
  echo "ERROR $0: Immutable archive file doesn't exist: s3://${ARTIFACT_BUCKET_NAME}/$SLUGNAME/artifacts/$immutable_archive_file"
  exit 1
else
  aws \
    --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp \
    "s3://${ARTIFACT_BUCKET_NAME}/$SLUGNAME/artifacts/$immutable_archive_file"  \
    "$tmp_artifact"
fi

# Extract the immutable archive file to the immutable bucket.
immutable_tmp_dir="$(mktemp -d)"
tar x -z -f "$tmp_artifact" -C "$immutable_tmp_dir"

# Create a version.txt file in the immutable directory so it can be used for
# version verification.
printf "%s" "${VERSION}" > "$immutable_tmp_dir/$SLUGNAME/version.txt"
aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  "$immutable_tmp_dir/$SLUGNAME/version.txt" \
  "s3://${IMMUTABLE_BUCKET_NAME}/${SLUGNAME}/versions/${VERSION}/version.txt" \
  --cache-control 'public, max-age:31536000, immutable' \
  --acl 'public-read'

aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  "$immutable_tmp_dir/$SLUGNAME/" \
  "s3://${IMMUTABLE_BUCKET_NAME}/${SLUGNAME}/immutable/" \
  --cache-control 'public, max-age:31536000, immutable' \
  --acl 'public-read' \
  --recursive
