#!/usr/bin/env sh

set -o errexit

tmp_output_file=$1

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

gpg_key_name="chillbox_doterra__${WORKSPACE}"
encrypted_tfstate="/var/lib/doterra/$WORKSPACE-terraform.tfstate.json.asc"

rm -f "$tmp_output_file"

if [ -e "$encrypted_tfstate" ]; then
  echo "INFO $0: Decrypting file '${encrypted_tfstate}' to '${tmp_output_file}'"
  gpg --quiet --decrypt "${encrypted_tfstate}" > "${tmp_output_file}"
fi

cd /usr/local/src/chillbox-terraform

terraform workspace select "$WORKSPACE" || \
  terraform workspace new "$WORKSPACE"

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "Sanity check to make sure workspace selected matches environment has failed." && exit 1)

# Initially the tfstate file could not exist or may be empty.
if [ -e "$tmp_output_file" ] && [ -s "$tmp_output_file" ]; then
  terraform state push "$tmp_output_file"
fi

terraform state pull > "$tmp_output_file"

rm -f "${encrypted_tfstate}"
gpg --encrypt --recipient "${gpg_key_name}" --armor --output "${encrypted_tfstate}" \
  --comment "Chillbox doterra tfstate" \
  --comment "Terraform workspace: $WORKSPACE" \
  --comment "Date: $(date)" \
  "$tmp_output_file"
