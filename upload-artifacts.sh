#!/usr/bin/env bash

set -o errexit

working_dir=$(realpath $(dirname $0))

# Need to use a log file for stdout since the stdout could be parsed as JSON by
# terraform external data source.
LOG_FILE="$working_dir/$0.log"
echo $(date) > $LOG_FILE

showlog () {
  # Terraform external data will need to echo to stderr to show the message to
  # the user.
  >&2 echo "See log file: $LOG_FILE for further details."
  cat $LOG_FILE
}
trap showlog err

test -n "$AWS_ACCESS_KEY_ID" || (echo "No AWS_ACCESS_KEY_ID set." >> $LOG_FILE && exit 1)
test -n "$AWS_SECRET_ACCESS_KEY" || (echo "No AWS_SECRET_ACCESS_KEY set." >> $LOG_FILE && exit 1)

# Extract and set shell variables from JSON input
eval "$(jq -r '@sh "
  SITES_ARTIFACT=\(.sites_artifact)
  CHILLBOX_ARTIFACT=\(.chillbox_artifact)
  SITES_MANIFEST=\(.sites_manifest)
  immutable_bucket_name=\(.immutable_bucket_name)
  artifact_bucket_name=\(.artifact_bucket_name)
  endpoint_url=\(.endpoint_url)
  "')"
echo "set shell variables from JSON stdin" >> $LOG_FILE
echo "  SITES_ARTIFACT=$SITES_ARTIFACT" >> $LOG_FILE
echo "  CHILLBOX_ARTIFACT=$CHILLBOX_ARTIFACT" >> $LOG_FILE
echo "  SITES_MANIFEST=$SITES_MANIFEST" >> $LOG_FILE
echo "  immutable_bucket_name=$immutable_bucket_name" >> $LOG_FILE
echo "  artifact_bucket_name=$artifact_bucket_name" >> $LOG_FILE
echo "  endpoint_url=$endpoint_url" >> $LOG_FILE

aws configure set default.s3.max_concurrent_requests 1

# Upload chillbox artifact file
if [ ! -n "$chillbox_artifact_exists" ]; then
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp "$working_dir/dist/$CHILLBOX_ARTIFACT" \
    s3://${artifact_bucket_name}/chillbox/$CHILLBOX_ARTIFACT >> $LOG_FILE
else
  echo "No changes to existing chillbox artifact: $CHILLBOX_ARTIFACT" >> $LOG_FILE
fi
# Upload site artifact file
if [ ! -n "$sites_artifact_exists" ]; then
  aws \
    --endpoint-url "$endpoint_url" \
    s3 cp "$working_dir/dist/$SITES_ARTIFACT" \
    s3://${artifact_bucket_name}/_sites/$SITES_ARTIFACT >> $LOG_FILE
else
  echo "No changes to existing site artifact: $SITES_ARTIFACT" >> $LOG_FILE
fi

jq -r '.[]' $SITES_MANIFEST \
  | while read -r artifact_file; do
    test -n "${artifact_file}" || continue
    slugname=$(dirname $artifact_file)
    artifact=$(basename $artifact_file)

    artifact_exists=$(aws \
      --endpoint-url "$endpoint_url" \
      s3 ls \
      s3://${artifact_bucket_name}/$slugname/artifacts/$artifact || printf '')
    if [ ! -n "$artifact_exists" ]; then
      echo "Uploading artifact: $artifact_file" >> $LOG_FILE
      aws \
        --endpoint-url "$endpoint_url" \
        s3 cp "$working_dir/dist/$artifact_file" \
        s3://${artifact_bucket_name}/$slugname/artifacts/$artifact >> $LOG_FILE
    else
      echo "No changes to existing artifact: $artifact_file" >> $LOG_FILE
    fi
  done

jq --null-input \
  --arg sites_artifact "$SITES_ARTIFACT" \
  --arg chillbox_artifact "$CHILLBOX_ARTIFACT" \
  --argjson sites_immutable_and_artifacts "$(jq -r -c '.' $SITES_MANIFEST)" \
  '{
    sites_artifact:$sites_artifact,
    chillbox_artifact:$chillbox_artifact,
    sites:$sites_immutable_and_artifacts
  }'
