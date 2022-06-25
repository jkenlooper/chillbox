#!/usr/bin/env sh

set -o errexit

encrypted_file=$1
decrypted_file=$2


test -n "$encrypted_file" || (echo "ERROR $0: first arg is empty. This should be the encrypted file." && exit 1)

test -n "$decrypted_file" || (echo "ERROR $0: second arg is empty. This should be the decrypted file to output." && exit 1)
test -e "$decrypted_file" || (echo "ERROR $0: decrypted file doesn't exist ($decrypted_file)." && exit 1)

# Sanity check that these were set.
test -n "$GPG_KEY_NAME" || (echo "ERROR $0: GPG_KEY_NAME variable is empty" && exit 1)

echo "INFO $0: Encrypting file '${decrypted_file}' to '${encrypted_file}'"

rm -f "${encrypted_file}"
gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "${encrypted_file}" \
  --comment "Date: $(date)" \
  "$decrypted_file"
