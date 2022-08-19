#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$0")")"

# Need to use a log file for stdout since the stdout could be parsed as JSON by
# terraform external data source.
LOG_FILE="${LOG_FILE:-$working_dir/$0.log}"
echo "INFO $0: Date: $(date)" > "$LOG_FILE"

showlog () {
  # Terraform external data will need to echo to stderr to show the message to
  # the user.
  >&2 echo "INFO $0: See log file: $LOG_FILE for further details."
}
trap showlog EXIT

test -n "$AWS_PROFILE" || (echo "ERROR $0: No AWS_PROFILE set." >> "$LOG_FILE" && exit 1)

# Extract and set shell variables from JSON input
SITES_ARTIFACT=""
CHILLBOX_ARTIFACT=""
sites_manifest_file=""
immutable_bucket_name=""
artifact_bucket_name=""
endpoint_url=""
eval "$(jq -r '@sh "
  SITES_ARTIFACT=\(.sites_artifact)
  CHILLBOX_ARTIFACT=\(.chillbox_artifact)
  sites_manifest_file=\(.sites_manifest)
  immutable_bucket_name=\(.immutable_bucket_name)
  artifact_bucket_name=\(.artifact_bucket_name)
  endpoint_url=\(.endpoint_url)
  "')"
{
  echo "INFO $0: set shell variables from JSON stdin"
  echo "  SITES_ARTIFACT=$SITES_ARTIFACT"
  echo "  CHILLBOX_ARTIFACT=$CHILLBOX_ARTIFACT"
  echo "  sites_manifest_file=$sites_manifest_file"
  echo "  immutable_bucket_name=$immutable_bucket_name"
  echo "  artifact_bucket_name=$artifact_bucket_name"
  echo "  endpoint_url=$endpoint_url"
} >> "$LOG_FILE"

# Upload chillbox artifact file
chillbox_artifact_exists="$(aws \
  --endpoint-url "$endpoint_url" \
  s3 ls \
  "s3://${artifact_bucket_name}/chillbox/$CHILLBOX_ARTIFACT" 2>> "$LOG_FILE" || printf "")"
if [ -z "$chillbox_artifact_exists" ]; then
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp "$working_dir/dist/$CHILLBOX_ARTIFACT" \
    "s3://${artifact_bucket_name}/chillbox/$CHILLBOX_ARTIFACT" >> "$LOG_FILE"
else
  echo "INFO $0: No changes to existing chillbox artifact: $CHILLBOX_ARTIFACT" >> "$LOG_FILE"
fi
# Upload site artifact file
sites_artifact_exists="$(aws \
  --endpoint-url "$endpoint_url" \
  s3 ls \
  "s3://${artifact_bucket_name}/_sites/$SITES_ARTIFACT" 2>> "$LOG_FILE" || printf "")"
if [ -z "$sites_artifact_exists" ]; then
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp "$working_dir/dist/$SITES_ARTIFACT" \
    "s3://${artifact_bucket_name}/_sites/$SITES_ARTIFACT" >> "$LOG_FILE"
else
  echo "INFO $0: No changes to existing site artifact: $SITES_ARTIFACT" >> "$LOG_FILE"
fi

jq -r '.[]' "$sites_manifest_file" \
  | while read -r artifact_file; do
    test -n "${artifact_file}" || continue
    slugname="$(dirname "$artifact_file")"
    artifact="$(basename "$artifact_file")"

    artifact_exists="$(aws \
      --endpoint-url "$endpoint_url" \
      s3 ls \
      "s3://${artifact_bucket_name}/$slugname/artifacts/$artifact" 2>> "$LOG_FILE" || printf "")"
    if [ -z "$artifact_exists" ]; then
      echo "INFO $0: Uploading artifact: $artifact_file" >> "$LOG_FILE"
      aws \
        --endpoint-url "$endpoint_url" \
        s3 cp "$working_dir/dist/sites/$artifact_file" \
        "s3://${artifact_bucket_name}/$slugname/artifacts/$artifact" >> "$LOG_FILE"
    else
      echo "INFO $0: No changes to existing artifact: $artifact_file" >> "$LOG_FILE"
    fi
  done

jq --null-input \
  --arg sites_artifact "$SITES_ARTIFACT" \
  --arg chillbox_artifact "$CHILLBOX_ARTIFACT" \
  --argjson sites_immutable_and_artifacts "$(jq -r -c '.' "$sites_manifest_file")" \
  '{
    sites_artifact:$sites_artifact,
    chillbox_artifact:$chillbox_artifact,
    sites:$sites_immutable_and_artifacts
  }'
