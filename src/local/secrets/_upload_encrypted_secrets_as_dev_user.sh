#!/usr/bin/env sh

set -o errexit

decrypted_terraform_spaces="$1"
test -n "$decrypted_terraform_spaces" || (echo "ERROR $0: First arg is not set." && exit 1)
test -e "$decrypted_terraform_spaces" || (echo "ERROR $0: Missing $decrypted_terraform_spaces file." && exit 1)

endpoint_url=""
artifact_bucket_name=""
eval "$(jq -r 'map_values(.value) | @sh "
endpoint_url=\(.s3_endpoint_url)
artifact_bucket_name=\(.artifact_bucket_name)
"' /var/lib/terraform-010-infra/output.json)"

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
  "/var/lib/encrypted-secrets/" \
  "s3://${artifact_bucket_name}/chillbox/encrypted-secrets/"
