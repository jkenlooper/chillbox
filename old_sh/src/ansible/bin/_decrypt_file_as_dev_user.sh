#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

ciphertext_file=$1
plaintext_file=$2

test -n "$ciphertext_file" || (echo "ERROR $script_name: first arg is empty. This should be the encrypted file." && exit 1)
test -e "$ciphertext_file" || (echo "ERROR $script_name: encrypted file doesn't exist ($ciphertext_file)." && exit 1)

test -n "$plaintext_file" || (echo "ERROR $script_name: second arg is empty. This should be the decrypted file to output." && exit 1)
rm -f "$plaintext_file"
touch "$plaintext_file" || (echo "ERROR $script_name: Failed to touch file at $plaintext_file" && exit 1)
chmod 0600 "$plaintext_file"


echo "INFO $script_name: Decrypting file ${ciphertext_file} to plaintext ${plaintext_file}"
gpg --quiet --decrypt "${ciphertext_file}" >> "${plaintext_file}"
