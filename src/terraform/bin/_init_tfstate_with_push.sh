#!/usr/bin/env sh

set -o errexit

echo "INFO $0: Initializing terraform state by decrypting the $ENCRYPTED_TFSTATE file if the $DECRYPTED_TFSTATE file doesn't exist."
# Only push the tfstate initially if it hasn't already been decrypted.
if [ -e "$ENCRYPTED_TFSTATE" ] && [ ! -e "$DECRYPTED_TFSTATE" ]; then
  set -x
  _dev_tty.sh "
    _decrypt_file_as_dev_user.sh \"$ENCRYPTED_TFSTATE\" \"$DECRYPTED_TFSTATE\""
  set +x

  if [ -s "$DECRYPTED_TFSTATE" ]; then
    set -x
    su dev -c "
        _doterra_state_push_as_dev_user.sh \"$DECRYPTED_TFSTATE\""
    set +x
  fi
fi

