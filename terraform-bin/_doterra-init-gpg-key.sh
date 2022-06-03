#!/usr/bin/env sh

set -o errexit

test -n "$GPG_KEY_NAME" || (echo "ERROR $0: GPG_KEY_NAME variable is empty" && exit 1)

# Create an encryption key if one doesn't already exist.  Set expiration to
# 'never' and use the default algorithm.
qgk_err_code=0
gpg --quick-generate-key "${GPG_KEY_NAME}" default encrypt never || qgk_err_code=$?

if [ $qgk_err_code -eq 2 ] || [ $qgk_err_code -eq 1 ] || [ $qgk_err_code -eq 0 ]; then
  if [ $qgk_err_code -eq 2 ] || [ $qgk_err_code -eq 1 ]; then
    echo "INFO $0: Using existing key: ${GPG_KEY_NAME}"
  elif [ $qgk_err_code -eq 0 ]; then
    echo "INFO $0: Using new key: ${GPG_KEY_NAME}"
  else
    # This shouldn't execute, but echo an ERROR in case the if block changes.
    echo "ERROR $0: Oops. The command 'gpg --quick-generate-key \"${GPG_KEY_NAME}\" default encrypt never' exited with error code: $qgk_err_code. Check the above conditions."
    exit 10
  fi
else
  echo "ERROR $0: Failed running command: 'gpg --quick-generate-key \"${GPG_KEY_NAME}\" default encrypt never' exited with error code: $qgk_err_code"
  exit 1
fi

# TODO No longer doing this since the gpg key to decrypt site secrets will only
# live on the chillbox server.
## Export the public gpg key for this workspace so the site secrets can be
## encrypted and uploaded to the s3 artifact bucket.
#gpg --list-keys
#gpg --armor --output "${GPG_KEY_NAME}.gpg" --export "${GPG_KEY_NAME}"
