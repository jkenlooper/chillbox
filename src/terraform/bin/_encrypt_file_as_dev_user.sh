#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

ciphertext_file=$1
plaintext_file=$2

test -n "$ciphertext_file" || (echo "ERROR $script_name: first arg is empty. This should be the output file path." && exit 1)

test -n "$plaintext_file" || (echo "ERROR $script_name: second arg is empty. This should be the plaintext file to encrypt." && exit 1)
test -e "$plaintext_file" || (echo "ERROR $script_name: plaintext file doesn't exist ($plaintext_file)." && exit 1)

# Sanity check that these were set.
test -n "$GPG_KEY_NAME" || (echo "ERROR $script_name: GPG_KEY_NAME variable is empty" && exit 1)

echo "INFO $script_name: Encrypting plaintext file '${plaintext_file}' to ciphertext file '${ciphertext_file}'"

rm -f "${ciphertext_file}"
gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "${ciphertext_file}" \
  --comment "Date: $(date)" \
  "$plaintext_file"
