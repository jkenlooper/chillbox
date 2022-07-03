#!/usr/bin/env sh

set -o errexit

encrypted_file=$1
decrypted_file=$2

test -n "$encrypted_file" || (echo "ERROR $0: first arg is empty. This should be the encrypted file." && exit 1)
test -e "$encrypted_file" || (echo "ERROR $0: encrypted file doesn't exist ($encrypted_file)." && exit 1)

test -n "$decrypted_file" || (echo "ERROR $0: second arg is empty. This should be the decrypted file to output." && exit 1)
touch "$decrypted_file" || (echo "ERROR $0: Failed to touch file at $decrypted_file" && exit 1)


echo "INFO $0: Decrypting file ${encrypted_file} to ${decrypted_file}"
gpg --quiet --decrypt "${encrypted_file}" > "${decrypted_file}"
