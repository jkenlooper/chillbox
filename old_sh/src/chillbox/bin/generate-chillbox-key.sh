#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

bin_dir="$(dirname "$0")"

current_user="$(id -u -n)"
test "$current_user" = "root" || (echo "ERROR $script_name: Must be root." && exit 1)

test -n "${S3_ENDPOINT_URL}" || (echo "ERROR $script_name: S3_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $script_name: Using S3_ENDPOINT_URL '${S3_ENDPOINT_URL}'"

test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $script_name: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

test -n "$AWS_PROFILE" || (echo "ERROR $script_name: No AWS_PROFILE set." && exit 1)

key_name="$(hostname -s | xargs)"
public_pem_key="/home/dev/.local/share/chillbox/keys/$key_name.public.pem"
private_pem_key="/home/dev/.local/share/chillbox/keys/$key_name.private.pem"
su dev -c "mkdir -p /home/dev/.local/share/chillbox/keys"
su dev -c "$bin_dir/generate-new-chillbox-keys -n '$key_name' -d /home/dev/.local/share/chillbox/keys"
test -e "$public_pem_key" || (echo "ERROR $script_name: No public pem key generated." && exit 1)
test -e "$private_pem_key" || (echo "ERROR $script_name: No private pem key generated." && exit 1)

s5cmd cp \
  "$public_pem_key" \
  "s3://${ARTIFACT_BUCKET_NAME}/chillbox/public-keys/$key_name.public.pem"