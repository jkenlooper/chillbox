#!/usr/bin/env sh

set -o errexit

tmp_pub_key="$1"
test -n "$tmp_pub_key" || (echo "ERROR $0: No tmp pub key file set as first arg. Exiting" && exit 1)
test -f "$tmp_pub_key" || (echo "ERROR $0: No tmp pub key file at $tmp_pub_key" && exit 1)
test -w "$tmp_pub_key" || (echo "ERROR $0: The tmp pub key file at $tmp_pub_key is not writable by the user" && exit 1)

command -v gpg > /dev/null

test -n "$CHILLBOX_GPG_KEY_NAME" || (echo "ERROR $0: No CHILLBOX_GPG_KEY_NAME set. Exiting" && exit 1)
user="$(id -un)"
hostname="$(hostname)"
key_name="$CHILLBOX_GPG_KEY_NAME"

chillbox_gpg_passphrase="${CHILLBOX_GPG_PASSPHRASE:-}"
if [ -z "$chillbox_gpg_passphrase" ]; then
  printf '\n%s\n' "No CHILLBOX_GPG_PASSPHRASE variable set. Please enter passphrase to use for the $key_name gpg key:"
  stty -echo
  read -r chillbox_gpg_passphrase
  stty echo
fi
test -n "$chillbox_gpg_passphrase" || (echo "ERROR $0: CHILLBOX_GPG_PASSPHRASE variable is empty" && exit 1)

# Remove any existing gpg key first before creating new one. There can be
# multiple matches for a key name.
fingerprint="$(gpg --with-colons --keyid-format=none --list-keys "$key_name" 2>/dev/null | awk -F: '/^fpr:/ { print $10 }' || echo '')"
test -z "$fingerprint" || (
  for f in $fingerprint; do
    gpg --yes --batch --delete-secret-and-public-key "$f"
  done
  )

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
gpg --yes --armor --output "$tmp_pub_key" --export "${key_name}"

