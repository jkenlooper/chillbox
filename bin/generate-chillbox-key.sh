#!/usr/bin/env sh

set -o errexit

command -v gpg > /dev/null

# TODO Support more than a single chillbox by setting a unique key_name instead of simply 'chillbox'.
key_name="chillbox"
user="$(id -un)"
hostname="$(hostname)"

test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

test -n "$AWS_PROFILE" || (echo "ERROR $0: No AWS_PROFILE set." && exit 1)

chillbox_gpg_passphrase="${CHILLBOX_GPG_PASSPHRASE:-}"
if [ -z "$chillbox_gpg_passphrase" ]; then
  printf '\n%s\n' "No CHILLBOX_GPG_PASSPHRASE variable set. Please enter passphrase to use for the $key_name gpg key:"
  stty -echo
  read -r chillbox_gpg_passphrase
  stty echo
fi
test -n "$chillbox_gpg_passphrase" || (echo "ERROR $0: CHILLBOX_GPG_PASSPHRASE variable is empty" && exit 1)

# Remove any existing gpg key first before creating new one.
fingerprint="$(gpg --with-colons --keyid-format=none --list-keys chillbox 2>/dev/null | awk -F: '/^fpr:/ { print $10 }' || echo '')"
test -z "$fingerprint" || gpg --yes --batch --delete-secret-and-public-key "$fingerprint"

# Use gpg batch generate key option so the passphrase for the gpg key can be set
# without interaction.
# https://www.gnupg.org/documentation/manuals/gnupg-devel/Unattended-GPG-key-generation.html#Unattended-GPG-key-generation
echo "
%echo Creating '$key_name' gpg key for '$user' user

# Key-Type is always first and set to the default algorithm
Key-Type: default

Key-Usage: encrypt

# Set expiration to never
Expire-Date: 0

Name-Real: $key_name
Name-Comment: $0
Name-Email: ${user}@${hostname}

Passphrase: $chillbox_gpg_passphrase
" | gpg --yes --batch --generate-key

# Export and upload the public key so other services can encrypt secret files
# using the public key.
tmp_pub_key="$(mktemp)"
gpg --yes --armor --output "$tmp_pub_key" --export "${key_name}"
aws \
  --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp \
  "$tmp_pub_key" \
  "s3://${ARTIFACT_BUCKET_NAME}/chillbox/gpg_pubkey/$key_name.gpg"
rm -f "$tmp_pub_key"
