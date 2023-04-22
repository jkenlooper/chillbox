#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

echo "INFO $script_name: Initializing terraform state by decrypting the $ENCRYPTED_TFSTATE file if the $DECRYPTED_TFSTATE file doesn't exist."
# Only push the tfstate initially if it hasn't already been decrypted.
if [ -e "$ENCRYPTED_TFSTATE" ] && [ ! -e "$DECRYPTED_TFSTATE" ]; then
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"$ENCRYPTED_TFSTATE\" \"$DECRYPTED_TFSTATE\""

  if [ -s "$DECRYPTED_TFSTATE" ]; then
    su dev -c "
        _doterra_state_push_as_dev_user.sh \"$DECRYPTED_TFSTATE\""
  fi
fi

