#!/usr/bin/env sh

set -o errexit
set -o nounset

script_name="$(basename "$0")"

terraform_command="$1"
decrypted_terraform_spaces="$2"
plaintext_terraform_010_infra_output_file="$3"

mkdir -p /run/tmp/secrets/logs
chmod -R 0700 /run/tmp/secrets/logs
export LOG_FILE="/run/tmp/secrets/logs/doterra-upload-artifacts.log"
touch "$LOG_FILE"

echo "INFO $script_name: jq version: $(jq --version)"

if [ ! -f "$plaintext_terraform_010_infra_output_file" ]; then
  echo "ERROR $script_name: Missing file: $plaintext_terraform_010_infra_output_file"
  exit 1
fi

cd /usr/local/src/chillbox-terraform

# Set the SITES_ARTIFACT CHILLBOX_ARTIFACT SITES_MANIFEST vars
# shellcheck disable=SC1091
. /var/lib/chillbox-build-artifacts-vars

jq \
  --arg jq_sites_artifact "${SITES_ARTIFACT}" \
  --arg jq_chillbox_artifact "${CHILLBOX_ARTIFACT}" \
  --arg jq_sites_manifest "${SITES_MANIFEST}" \
  '{
  sites_artifact: $jq_sites_artifact,
  chillbox_artifact: $jq_chillbox_artifact,
  sites_manifest: $jq_sites_manifest,
  } + map_values(.value)' \
  "$plaintext_terraform_010_infra_output_file" \
  > chillbox_sites.auto.tfvars.json
chown dev:dev chillbox_sites.auto.tfvars.json

endpoint_url=""
immutable_bucket_name=""
artifact_bucket_name=""
eval "$(jq -r '@sh "
endpoint_url=\(.s3_endpoint_url)
immutable_bucket_name=\(.immutable_bucket_name)
artifact_bucket_name=\(.artifact_bucket_name)
"' chillbox_sites.auto.tfvars.json)"

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

sites_manifest_file="$(realpath "./dist/$SITES_MANIFEST")"

if [ "$terraform_command" != "destroy" ] && [ "$SKIP_UPLOAD" != "y" ]; then
  jq \
    --arg jq_immutable_bucket_name "$immutable_bucket_name" \
    --arg jq_artifact_bucket_name "$artifact_bucket_name" \
    --arg jq_endpoint_url "$endpoint_url" \
    --arg jq_sites_artifact "$SITES_ARTIFACT" \
    --arg jq_chillbox_artifact "$CHILLBOX_ARTIFACT" \
    --arg jq_sites_manifest "$sites_manifest_file" \
    --null-input '{
      sites_artifact: $jq_sites_artifact,
      chillbox_artifact: $jq_chillbox_artifact,
      sites_manifest: $jq_sites_manifest,
      immutable_bucket_name: $jq_immutable_bucket_name,
      artifact_bucket_name: $jq_artifact_bucket_name,
      endpoint_url: $jq_endpoint_url,
    }' | ./upload-artifacts.sh || (echo "ERROR $script_name: ./upload-artifacts.sh failed." && cat "${LOG_FILE}" && exit 1)
fi
cat "${LOG_FILE}"
