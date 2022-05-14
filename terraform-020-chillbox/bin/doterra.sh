#!/usr/bin/env sh

set -o errexit

terraform_command=$1
if [ "$terraform_command" != "plan" ] && [ "$terraform_command" != "apply" ] && [ "$terraform_command" != "destroy" ]; then
  echo "This command is not supported when using $0 script."
  exit 1
fi


encrypted_credentials_tfvars_file=/var/lib/doterra/credentials.tfvars.json.asc
secure_tmp_secrets_dir=/run/tmp/secrets/doterra
decrypted_credentials_tfvars_file="${secure_tmp_secrets_dir}/credentials.tfvars.json"
if [ ! -f "${decrypted_credentials_tfvars_file}" ]; then
  echo "INFO $0: Decrypting file '${encrypted_credentials_tfvars_file}' to '${decrypted_credentials_tfvars_file}'"
  test -d "/run/tmp/secrets" || (echo "ERROR $0: The path '/run/tmp/secrets' is not a directory" && exit 1)
  mkdir -p "${secure_tmp_secrets_dir}"
  chmod -R 0700 "${secure_tmp_secrets_dir}"
  gpg --quiet --decrypt "${encrypted_credentials_tfvars_file}" > "${decrypted_credentials_tfvars_file}"
fi

mkdir -p /run/tmp/secrets/logs
chmod -R 0700 /run/tmp/secrets/logs
export LOG_FILE="/run/tmp/secrets/logs/doterra-upload-artifacts.log"

echo "INFO $0: aws-cli version: $(aws --version)"
echo "INFO $0: jq version: $(jq --version)"

# Set the AWS credentials so upload-artifacts.sh can use them.
tmp_cred_csv="$(mktemp)"
jq -r '"User Name, Access Key ID, Secret Access Key
digitalocean-spaces-chillbox,\(.do_spaces_access_key_id),\(.do_spaces_secret_access_key)"' ${decrypted_credentials_tfvars_file} > "$tmp_cred_csv"
aws configure import --csv "file://$tmp_cred_csv"
export AWS_PROFILE=digitalocean-spaces-chillbox
rm "$tmp_cred_csv"

cd /usr/local/src/chillbox-terraform


terraform workspace select "$WORKSPACE" || \
  terraform workspace new "$WORKSPACE"

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "Sanity check to make sure workspace selected matches environment has failed." && exit 1)


if [ ! -f "/var/lib/terraform-010-infra/output.json" ]; then
  echo "Missing file: /var/lib/terraform-010-infra/output.json"
  exit 1
fi

jq \
  --arg jq_sites_artifact "${SITES_ARTIFACT}" \
  --arg jq_chillbox_artifact "${CHILLBOX_ARTIFACT}" \
  --arg jq_sites_manifest "${SITES_MANIFEST}" \
  '{
  sites_artifact: $jq_sites_artifact,
  chillbox_artifact: $jq_chillbox_artifact,
  sites_manifest: $jq_sites_manifest,
  } + map_values(.value)' \
  /var/lib/terraform-010-infra/output.json \
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

jq \
  --arg jq_immutable_bucket_name "$immutable_bucket_name" \
  --arg jq_artifact_bucket_name "$artifact_bucket_name" \
  --arg jq_endpoint_url "$endpoint_url" \
  --arg jq_sites_artifact "$SITES_ARTIFACT" \
  --arg jq_chillbox_artifact "$CHILLBOX_ARTIFACT" \
  --arg jq_sites_manifest "$SITES_MANIFEST" \
  --null-input '{
    sites_artifact: $jq_sites_artifact,
    chillbox_artifact: $jq_chillbox_artifact,
    sites_manifest: $jq_sites_manifest,
    immutable_bucket_name: $jq_immutable_bucket_name,
    artifact_bucket_name: $jq_artifact_bucket_name,
    endpoint_url: $jq_endpoint_url,
  }' | ./upload-artifacts.sh || (echo "ERROR $0: ./upload-artifacts.sh failed." && cat "${LOG_FILE}" && exit 1)


terraform \
  "$terraform_command" \
  -var-file="${decrypted_credentials_tfvars_file}"

