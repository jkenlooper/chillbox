#!/usr/bin/env bash

set -o errexit

command -v gpg > /dev/null

key_name="chillbox"
user="$(id -un)"
hostname="$(hostname)"

chillbox_gpg_passphrase="${CHILLBOX_GPG_PASSPHRASE:-}"
if [ -z "$chillbox_gpg_passphrase" ]; then
  read -r -s -p "
No CHILLBOX_GPG_PASSPHRASE variable set. Please enter passphrase to use for the $key_name gpg key:
" chillbox_gpg_passphrase
fi
test -n "$chillbox_gpg_passphrase" || (echo "ERROR $0: CHILLBOX_GPG_PASSPHRASE variable is empty" && exit 1)

# TODO Remove any existing gpg key first before creating new one.

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
" | gpg --batch --generate-key


echo "test file" > testfile.txt
gpg --encrypt --recipient "$key_name" --armor --output "testfile.txt.asc" \
  --comment "test" \
  testfile.txt
