#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

test -n "$GPG_KEY_NAME" || (echo "ERROR $script_name: GPG_KEY_NAME variable is empty" && exit 1)

# Create an encryption key if one doesn't already exist.  Set expiration to
# 'never' and use the default algorithm.
qgk_err_code=0
gpg --quick-generate-key "${GPG_KEY_NAME}" default encrypt never || qgk_err_code=$?

if [ $qgk_err_code -eq 2 ] || [ $qgk_err_code -eq 1 ] || [ $qgk_err_code -eq 0 ]; then
  if [ $qgk_err_code -eq 2 ] || [ $qgk_err_code -eq 1 ]; then
    echo "INFO $script_name: Using existing key: ${GPG_KEY_NAME}"
  elif [ $qgk_err_code -eq 0 ]; then
    echo "INFO $script_name: Using new key: ${GPG_KEY_NAME}"
  else
    # This shouldn't execute, but echo an ERROR in case the if block changes.
    echo "ERROR $script_name: Oops. The command 'gpg --quick-generate-key \"${GPG_KEY_NAME}\" default encrypt never' exited with error code: $qgk_err_code. Check the above conditions."
    exit 10
  fi
else
  echo "ERROR $script_name: Failed running command: 'gpg --quick-generate-key \"${GPG_KEY_NAME}\" default encrypt never' exited with error code: $qgk_err_code"
  exit 1
fi
