#!/usr/bin/env sh

set -o errexit

service_obj="$1"

$tmp_artifact
$slugname
 $slugdir
S3_ARTIFACT_ENDPOINT_URL
S3_ENDPOINT_URL
ARTIFACT_BUCKET_NAME
IMMUTABLE_BUCKET_NAME

export S3_ARTIFACT_ENDPOINT_URL=${S3_ARTIFACT_ENDPOINT_URL}
test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

export S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
test -n "${S3_ENDPOINT_URL}" || (echo "ERROR $0: S3_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ENDPOINT_URL '${S3_ENDPOINT_URL}'"

export ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

export IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
test -n "${IMMUTABLE_BUCKET_NAME}" || (echo "ERROR $0: IMMUTABLE_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using IMMUTABLE_BUCKET_NAME '${IMMUTABLE_BUCKET_NAME}'"

echo "INFO $0: Running site init"
