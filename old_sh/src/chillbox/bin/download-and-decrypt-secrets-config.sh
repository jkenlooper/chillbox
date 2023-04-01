#!/usr/bin/env sh

set -o errexit

bin_dir="$(dirname "$0")"
script_name="$(basename "$0")"

test -n "${SLUGNAME}" || (echo "ERROR $script_name: SLUGNAME variable is empty" && exit 1)
echo "INFO $script_name: Using slugname '${SLUGNAME}'"

# $SLUGNAME/$name/$secrets_config
secrets_config_path="$1"
test -n "$secrets_config_path" || (echo "ERROR $script_name: No arg passed in for secrets config path. Exiting" && exit 1)
secrets_config_file_name="$(basename "$secrets_config_path")"
secrets_config_dir="$(dirname "$secrets_config_path")"

hostname="$(hostname -s)"
key_name="$hostname"
S3_ENDPOINT_URL="${S3_ENDPOINT_URL:-}"
ARTIFACT_BUCKET_NAME="${ARTIFACT_BUCKET_NAME:-}"

test -n "$S3_ENDPOINT_URL" || (echo "ERROR $script_name: No S3_ENDPOINT_URL set. Exiting" && exit 1)
test -n "$ARTIFACT_BUCKET_NAME" || (echo "ERROR $script_name: No ARTIFACT_BUCKET_NAME set. Exiting" && exit 1)

tmp_encrypted_secret_config="$(mktemp)"
cleanup() {
  rm -f "$tmp_encrypted_secret_config"
}
trap cleanup EXIT

secrets_config_exists="$(s5cmd ls \
  "s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted-secrets/$secrets_config_dir/$hostname/$secrets_config_file_name" > /dev/null \
    && printf 'yes' \
    || printf 'no')"
if [ "$secrets_config_exists" = "no" ]; then
  echo "INFO $script_name: Service secrets config doesn't exist at: s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted-secrets/$secrets_config_dir/$hostname/$secrets_config_file_name"
  echo "INFO $script_name: Skipping download and decrypt secrets config for $secrets_config_path"
  exit 0
fi

s5cmd cp "s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted-secrets/$secrets_config_dir/$hostname/$secrets_config_file_name" \
  "$tmp_encrypted_secret_config"

decrypted_file="/run/tmp/chillbox_secrets/$secrets_config_path"
decrypted_file_dir="$(dirname "$decrypted_file")"
mkdir -p "$decrypted_file_dir"
chmod 770 "$decrypted_file_dir"
chown -R "$SLUGNAME":dev "$decrypted_file_dir"
chown dev:dev "$tmp_encrypted_secret_config"
echo "INFO $script_name: Decrypting file at s3://$ARTIFACT_BUCKET_NAME/chillbox/encrypted-secrets/$secrets_config_dir/$hostname/$secrets_config_file_name to $decrypted_file"

su dev -c "$bin_dir/decrypt-file -k '/home/dev/.local/share/chillbox/keys/$key_name.private.pem' -i '$tmp_encrypted_secret_config' '$decrypted_file'"
chown "$SLUGNAME":dev "$decrypted_file"
chmod 770 "$decrypted_file"

rm -f "$tmp_encrypted_secret_config"
