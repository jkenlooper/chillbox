#!/usr/bin/env sh

set -o errexit

bin_dir="$(dirname "$0")"

command -v gpg > /dev/null

current_user="$(id -u -n)"
test "$current_user" = "root" || (echo "ERROR $0: Must be root." && exit 1)

test -n "$CHILLBOX_GPG_KEY_NAME" || (echo "ERROR $0: No CHILLBOX_GPG_KEY_NAME set. Exiting" && exit 1)

key_name="$CHILLBOX_GPG_KEY_NAME"

test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

test -n "$AWS_PROFILE" || (echo "ERROR $0: No AWS_PROFILE set." && exit 1)

tmp_pub_key="$(mktemp)"
chown dev:dev "$tmp_pub_key"
"$bin_dir/_dev_tty.sh" "
  CHILLBOX_GPG_KEY_NAME=$CHILLBOX_GPG_KEY_NAME \
  CHILLBOX_GPG_PASSPHRASE=$CHILLBOX_GPG_PASSPHRASE \
    $bin_dir/generate-chillbox-key-as-dev-user.sh $tmp_pub_key"

aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  "$tmp_pub_key" \
  "s3://${ARTIFACT_BUCKET_NAME}/chillbox/gpg_pubkey/$key_name.gpg"
rm -f "$tmp_pub_key"
