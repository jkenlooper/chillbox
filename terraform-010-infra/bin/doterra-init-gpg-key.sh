#!/usr/bin/env sh

set -o errexit

# Sanity check for the terraform workspace being set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

gpg_key_name="$1"
test -n "$gpg_key_name" || (echo "ERROR $0: gpg_key_name variable is empty" && exit 1)

# Create an encryption key if one doesn't already exist.  Set expiration to
# 'never' and use the default algorithm.
qgk_err_code=0
gpg --quick-generate-key "${gpg_key_name}" default encrypt never || qgk_err_code=$?

if [ $qgk_err_code -eq 2 -o $qgk_err_code -eq 1 -o $qgk_err_code -eq 0 ]; then
  if [ $qgk_err_code -eq 2 -o $qgk_err_code -eq 1 ]; then
    echo "INFO $0: Using existing key: ${gpg_key_name}"
  elif [ $qgk_err_code -eq 0 ]; then
    echo "INFO $0: Using new key: ${gpg_key_name}"
  else
    # Oops. Check the above conditions.
    exit 10
  fi
else
  echo "ERROR $0: Failed running command: 'gpg --quick-generate-key \"${gpg_key_name}\" default encrypt never' exited with error code: $qgk_err_code"
  exit 1
fi
