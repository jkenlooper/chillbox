#!/usr/bin/env sh

set -o errexit

encrypted_file=$1
decrypted_file=$2


test -n "$encrypted_file" || (echo "ERROR $0: first arg is empty. This should be the encrypted file." && exit 1)

test -n "$decrypted_file" || (echo "ERROR $0: second arg is empty. This should be the decrypted file to output." && exit 1)
test -e "$decrypted_file" || (echo "ERROR $0: decrypted file doesn't exist ($decrypted_file)." && exit 1)

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
test -n "$gpg_key_name" || (echo "ERROR $0: gpg_key_name variable is empty" && exit 1)

echo "INFO $0: Encrypting file '${decrypted_file}' to '${encrypted_file}'"

rm -f "${encrypted_file}"
gpg --encrypt --recipient "${gpg_key_name}" --armor --output "${encrypted_file}" \
  --comment "Terraform workspace: $WORKSPACE" \
  --comment "Date: $(date)" \
  "$decrypted_file"
