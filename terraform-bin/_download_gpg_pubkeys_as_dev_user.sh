#!/usr/bin/env sh

set -o errexit

decrypted_credentials_tfvars_file="$1"
test -n "$decrypted_credentials_tfvars_file" || (echo "ERROR $0: First arg is not set." && exit 1)
test -e "$decrypted_credentials_tfvars_file" || (echo "ERROR $0: Missing $decrypted_credentials_tfvars_file file." && exit 1)

endpoint_url=""
artifact_bucket_name=""
eval "$(jq -r 'map_values(.value) | @sh "
endpoint_url=\(.s3_endpoint_url)
artifact_bucket_name=\(.artifact_bucket_name)
"' /var/lib/terraform-010-infra/output.json)"


tmp_cred_csv="/run/tmp/secrets/tmp_cred.csv"
jq -r '"User Name, Access Key ID, Secret Access Key
chillbox_object_storage,\(.do_spaces_access_key_id),\(.do_spaces_secret_access_key)"' "${decrypted_credentials_tfvars_file}" > "$tmp_cred_csv"
aws configure import --csv "file://$tmp_cred_csv"
export AWS_PROFILE=chillbox_object_storage
shred -fu "$tmp_cred_csv" || rm -f "$tmp_cred_csv"

# aws s3 download
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp \
  --recursive \
  "s3://${artifact_bucket_name}/chillbox/gpg_pubkey/" \
  "/var/lib/gpg_pubkey/"
