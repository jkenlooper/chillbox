#!/usr/bin/env sh

set -o errexit

# $SLUGNAME/$service_handler/$service_secrets_config
service_secrets_config_path="$1"
test -n "$service_secrets_config_path" || (echo "ERROR $0: No arg passed in for service secrets config path. Exiting" && exit 1)
service_secrets_config_file_name="$(basename "$service_secrets_config_path")".asc
service_secrets_config_dir="$(dirname "$service_secrets_config_path")"

CHILLBOX_GPG_KEY_NAME="${CHILLBOX_GPG_KEY_NAME:-}"
S3_ENDPOINT_URL="${S3_ENDPOINT_URL:-}"
ARTIFACT_BUCKET_NAME="${ARTIFACT_BUCKET_NAME:-}"

# TODO Verify that this has already been done?
# shellcheck disable=SC1091
# . /home/dev/.env

test -n "$CHILLBOX_GPG_KEY_NAME" || (echo "ERROR $0: No CHILLBOX_GPG_KEY_NAME set. Exiting" && exit 1)
test -n "$S3_ENDPOINT_URL" || (echo "ERROR $0: No S3_ENDPOINT_URL set. Exiting" && exit 1)
test -n "$ARTIFACT_BUCKET_NAME" || (echo "ERROR $0: No ARTIFACT_BUCKET_NAME set. Exiting" && exit 1)

tmp_encrypted_secret_config="$(mktemp)"
cleanup() {
  rm -f "$tmp_encrypted_secret_config"
}
trap cleanup EXIT

service_secrets_config_exists="$(aws \
  --endpoint-url "$S3_ENDPOINT_URL" \
  s3 ls \
  "s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted_secrets/$service_secrets_config_dir/$CHILLBOX_GPG_KEY_NAME/$service_secrets_config_file_name" > /dev/null \
    && printf 'yes' \
    || printf 'no')"
if [ "$service_secrets_config_exists" = "no" ]; then
  echo "INFO $0: Service secrets config doesn't exist at: s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted_secrets/$service_secrets_config_dir/$CHILLBOX_GPG_KEY_NAME/$service_secrets_config_file_name"
  echo "INFO $0: Skipping download and decrypt secrets config for $service_secrets_config_path"
  exit 0
fi

aws \
  --endpoint-url "$S3_ENDPOINT_URL" \
  s3 cp "s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted_secrets/$service_secrets_config_dir/$CHILLBOX_GPG_KEY_NAME/$service_secrets_config_file_name" \
  "$tmp_encrypted_secret_config"

decrypted_file="/run/tmp/chillbox_secrets/$service_secrets_config_path"
mkdir -p "$(dirname "$decrypted_file")"

echo "INFO $0: Decrypting file at s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted_secrets/$service_secrets_config_dir/$CHILLBOX_GPG_KEY_NAME/$service_secrets_config_file_name to ${decrypted_file}"
su dev -c "gpg --quiet --decrypt '$tmp_encrypted_secret_config' > '${decrypted_file}'"

rm -f "$tmp_encrypted_secret_config"
