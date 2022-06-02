#!/usr/bin/env sh

set -o errexit

gpg_key_name="${gpg_key_name:-}"
test -n "$gpg_key_name" || (echo "ERROR $0: gpg_key_name variable is empty" && exit 1)

# Create an encryption key if one doesn't already exist.  Set expiration to
# 'never' and use the default algorithm.
qgk_err_code=0
gpg --quick-generate-key "${gpg_key_name}" default encrypt never || qgk_err_code=$?

if [ $qgk_err_code -eq 2 ] || [ $qgk_err_code -eq 1 ] || [ $qgk_err_code -eq 0 ]; then
  if [ $qgk_err_code -eq 2 ] || [ $qgk_err_code -eq 1 ]; then
    echo "INFO $0: Using existing key: ${gpg_key_name}"
  elif [ $qgk_err_code -eq 0 ]; then
    echo "INFO $0: Using new key: ${gpg_key_name}"
  else
    # This shouldn't execute, but echo an ERROR in case the if block changes.
    echo "ERROR $0: Oops. The command 'gpg --quick-generate-key \"${gpg_key_name}\" default encrypt never' exited with error code: $qgk_err_code. Check the above conditions."
    exit 10
  fi
else
  echo "ERROR $0: Failed running command: 'gpg --quick-generate-key \"${gpg_key_name}\" default encrypt never' exited with error code: $qgk_err_code"
  exit 1
fi

# TODO No longer doing this since the gpg key to decrypt site secrets will only
# live on the chillbox server.
## Export the public gpg key for this workspace so the site secrets can be
## encrypted and uploaded to the s3 artifact bucket.
#gpg --list-keys
#gpg --armor --output "${gpg_key_name}.gpg" --export "${gpg_key_name}"
