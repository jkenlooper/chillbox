#!/usr/bin/env sh

set -o errexit

tmp_input_file=$1

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

gpg_key_name="chillbox_doterra__${WORKSPACE}"
encrypted_tfstate="/var/lib/terraform-010-infra/$WORKSPACE-terraform.tfstate.json.asc"

decrypted_tfstate="/run/tmp/secrets/doterra/$WORKSPACE-terraform.tfstate.json"
rm -f "$decrypted_tfstate"

if [ -e "$encrypted_tfstate" ]; then
  echo "INFO $0: Decrypting file '${encrypted_tfstate}' to '${decrypted_tfstate}'"
  gpg --quiet --decrypt "${encrypted_tfstate}" > "${decrypted_tfstate}"
fi

cd /usr/local/src/chillbox-terraform

terraform workspace select "$WORKSPACE" || \
  terraform workspace new "$WORKSPACE"

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "Sanity check to make sure workspace selected matches environment has failed." && exit 1)

# Initially the tfstate file could not exist or may be empty.
if [ -e "$decrypted_tfstate" ] && [ -s "$decrypted_tfstate" ]; then
  terraform state push "$decrypted_tfstate"
fi

terraform state push "$tmp_input_file"
terraform state pull > "$decrypted_tfstate"

rm -f "${encrypted_tfstate}"
gpg --encrypt --recipient "${gpg_key_name}" --armor --output "${encrypted_tfstate}" \
  --comment "Chillbox doterra tfstate" \
  --comment "Terraform workspace: $WORKSPACE" \
  --comment "Date: $(date)" \
  "$decrypted_tfstate"
