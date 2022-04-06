#!/usr/bin/env bash

set -o errexit

working_dir=$(realpath $(dirname $0))

# Need to use a log file for stdout since the stdout will be parsed as JSON by
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
  immutable_bucket_name=\(.immutable_bucket_name)
  artifact_bucket_name=\(.artifact_bucket_name)
  endpoint_url=\(.endpoint_url)
  "')"
export SITES_ARTIFACT
export CHILLBOX_ARTIFACT
echo "set shell variables from JSON stdin" >> $LOG_FILE
echo "  SITES_ARTIFACT=$SITES_ARTIFACT" >> $LOG_FILE
echo "  CHILLBOX_ARTIFACT=$CHILLBOX_ARTIFACT" >> $LOG_FILE
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

sites_manifest_json="$working_dir/dist/sites.manifest.json"

jq -r '.[]' $sites_manifest_json \
  | while read -r artifact_file; do
    test -n "${artifact_file}" || continue
    echo "artifact file: $artifact_file" >> $LOG_FILE
    slugname=$(dirname $artifact_file)
    artifact=$(basename $artifact_file)

    artifact_exists=$(aws \
      --endpoint-url "$endpoint_url" \
      s3 ls \
      s3://${artifact_bucket_name}/$slugname/artifacts/$artifact || printf '')
    if [ ! -n "$artifact_exists" ]; then
      aws \
        --endpoint-url "$endpoint_url" \
        s3 cp "$working_dir/dist/$artifact_file" \
        s3://${artifact_bucket_name}/$slugname/artifacts/$artifact >> $LOG_FILE
    else
      echo "No changes to existing artifact: $artifact_file" >> $LOG_FILE
    fi
  done

#upload_immutable() {
#  archive_file=$1
#  immutable_tmp_dir=$(mktemp -d)
#  tar --directory=$immutable_tmp_dir --extract --gunzip -f $archive_file
#
#  aws \
#    --endpoint-url "$endpoint_url" \
#    s3 cp $immutable_tmp_dir/$slugname/ \
#    s3://${immutable_bucket_name}/${slugname}/${version} \
#    --cache-control 'public, max-age:31536000, immutable' \
#    --acl 'public-read' \
#    --recursive >> $LOG_FILE
#}
#
#upload_artifact() {
#  archive_file=$1
#  aws \
#    --endpoint-url "$endpoint_url" \
#    s3 cp $archive_file \
#    s3://${artifact_bucket_name}/${slugname}/ >> $LOG_FILE
#}


echo "SITES_ARTIFACT=$SITES_ARTIFACT" >> $LOG_FILE

##

jq --null-input \
  --arg sites_artifact "$SITES_ARTIFACT" \
  --arg chillbox_artifact "$CHILLBOX_ARTIFACT" \
  '{
    sites_artifact:$sites_artifact,
    chillbox_artifact:$chillbox_artifact
  }'
