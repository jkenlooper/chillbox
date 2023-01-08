#!/usr/bin/env sh

set -o errexit

ciphertext_file=$1
plaintext_file=$2

test -n "$ciphertext_file" || (echo "ERROR $0: first arg is empty. This should be the encrypted file." && exit 1)
test -e "$ciphertext_file" || (echo "ERROR $0: encrypted file doesn't exist ($ciphertext_file)." && exit 1)

test -n "$plaintext_file" || (echo "ERROR $0: second arg is empty. This should be the decrypted file to output." && exit 1)
rm -f "$plaintext_file"
touch "$plaintext_file" || (echo "ERROR $0: Failed to touch file at $plaintext_file" && exit 1)
chmod 0600 "$plaintext_file"


echo "INFO $0: Decrypting file ${ciphertext_file} to plaintext ${plaintext_file}"
gpg --quiet --decrypt "${ciphertext_file}" >> "${plaintext_file}"
