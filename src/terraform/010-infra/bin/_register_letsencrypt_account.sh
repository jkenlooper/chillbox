#!/usr/bin/env sh

# Check for an existing encrypted letsencrypt account; create a new one if it is
# missing.

set -o errexit

# Any files or directories created from this script should only be accessible by
# the user executing the script.
umask 0077

script_name="$(basename "$0")"
secure_tmp_secrets_dir="${secure_tmp_secrets_dir:-}"

# Sanity check that these were set.
test -n "$GPG_KEY_NAME" || (echo "ERROR $script_name: GPG_KEY_NAME variable is empty" && exit 1)
test -n "$secure_tmp_secrets_dir" || (echo "ERROR: secure_tmp_secrets_dir variable is empty." && exit 1)
test -d "$secure_tmp_secrets_dir" || (echo "ERROR $script_name: The path '$secure_tmp_secrets_dir' is not a directory" && exit 1)

ACME_SERVER="${ACME_SERVER:-''}"
test -n "${ACME_SERVER}" || (echo "ERROR $script_name: ACME_SERVER variable is empty" && exit 1)
echo "INFO $script_name: Using ACME_SERVER '${ACME_SERVER}'"

acme_hostname="$(echo "$ACME_SERVER" | sed -E 's%https://([^/]+)/?.*%\1%')"
encrypted_letsencrypt_account_archive="/var/lib/doterra/secrets/$acme_hostname-accounts-directory.tar.b64.asc"

if [ -f "$encrypted_letsencrypt_account_archive" ]; then
  echo "INFO $script_name: The encrypted letsencrypt account archive already exist at /var/lib/doterra/secrets/. Skipping the creation of a new files."
  exit 0
fi


# Only need to install certbot as needed.
python -m pip install --quiet --disable-pip-version-check \
  --no-index --find-links /var/lib/chillbox/python \
  certbot

cleanup() {
  echo "INFO $script_name: Clean up and remove $secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64"
  if [ -e "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64" ]; then
    # Fallback on rm command if shred fails.
    shred -z -u "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64" || rm -f "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64"
  fi
}
trap cleanup EXIT

mkdir -p "$(dirname "$encrypted_letsencrypt_account_archive")"

echo "No existing encrypted letsencrypt account archive exists at /var/lib/doterra/secrets/. Creating a new one."

certbot register \
  --user-agent-comment "chillbox/0.0" \
  --server "$ACME_SERVER"

tar c \
  -f - \
  -C "/etc/letsencrypt/accounts/$acme_hostname" \
  directory | base64 > "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64"
# Delete the account as it is no longer needed here.
chmod -R u+w /etc/letsencrypt/accounts/
find "/etc/letsencrypt/accounts/$acme_hostname" -type f \
  -exec sh -c 'shred -z -u "$1" || rm -f "$1"' shell {} \;

gpg --encrypt --recipient "${GPG_KEY_NAME}" --armor --output "$encrypted_letsencrypt_account_archive" \
  --comment "letsencrypt accounts directory" \
  --comment "Date: $(date)" \
  "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64"
shred -z -u "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64" || rm -f "$secure_tmp_secrets_dir/$acme_hostname-accounts-directory.tar.b64"
