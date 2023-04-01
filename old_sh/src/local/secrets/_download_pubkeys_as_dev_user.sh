#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

decrypted_terraform_spaces="$1"
test -n "$decrypted_terraform_spaces" || (echo "ERROR $script_name: First arg is not set." && exit 1)
test -e "$decrypted_terraform_spaces" || (echo "ERROR $script_name: Missing $decrypted_terraform_spaces file." && exit 1)

plaintext_terraform_010_infra_output_file="$2"
test -n "$plaintext_terraform_010_infra_output_file" || (echo "ERROR $script_name: Second arg is not set." && exit 1)
test -e "$plaintext_terraform_010_infra_output_file" || (echo "ERROR $script_name: Missing $plaintext_terraform_010_infra_output_file file." && exit 1)

endpoint_url=""
artifact_bucket_name=""
eval "$(jq -r 'map_values(.value) | @sh "
endpoint_url=\(.s3_endpoint_url)
artifact_bucket_name=\(.artifact_bucket_name)
"' "$plaintext_terraform_010_infra_output_file")"

# Set the credentials for accessing the s3 object storage
mkdir -p /home/dev/.aws
chown -R dev:dev /home/dev/.aws
chmod 0700 /home/dev/.aws
jq -r '"[chillbox_object_storage]
aws_access_key_id=\(.do_spaces_access_key_id)
aws_secret_access_key=\(.do_spaces_secret_access_key)"' "${decrypted_terraform_spaces}" > /home/dev/.aws/credentials
chmod 0600 /home/dev/.aws/credentials
chown dev:dev /home/dev/.aws/credentials

export AWS_PROFILE=chillbox_object_storage
export S3_ENDPOINT_URL="${endpoint_url}"

s5cmd cp \
  "s3://${artifact_bucket_name}/chillbox/public-keys/*" \
  "/var/lib/chillbox/public-keys/"
