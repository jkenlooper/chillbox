#!/usr/bin/env sh

set -o errexit

sites_artifact_file=${1:-""}

export SITES_ARTIFACT="${SITES_ARTIFACT}"
if [ -z "${sites_artifact_file}" ]; then
  test -n "${SITES_ARTIFACT}" || (echo "ERROR $0: SITES_ARTIFACT variable is empty" && exit 1)
  echo "INFO $0: Using SITES_ARTIFACT '${SITES_ARTIFACT}'"
fi

export S3_ARTIFACT_ENDPOINT_URL="${S3_ARTIFACT_ENDPOINT_URL}"
test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

export ARTIFACT_BUCKET_NAME="${ARTIFACT_BUCKET_NAME}"
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

export CHILLBOX_SERVER_PORT="${CHILLBOX_SERVER_PORT}"
test -n "${CHILLBOX_SERVER_PORT}" || (echo "ERROR $0: CHILLBOX_SERVER_PORT variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_SERVER_PORT '${CHILLBOX_SERVER_PORT}'"

echo "INFO $0: Running site init"


tmp_sites_artifact="$(mktemp)"

cleanup() {
  echo ""
  rm -f "$tmp_sites_artifact"
}
trap cleanup EXIT

# TODO: make a backup directory of previous sites and then compare new sites to
# find any sites that should be deleted. This would only be applicable to server
# version; not docker version.
if [ -z "${sites_artifact_file}" ]; then
  echo "INFO $0: Fetching sites artifact from s3://$ARTIFACT_BUCKET_NAME/_sites/$SITES_ARTIFACT"
  tmp_sites_artifact="$(mktemp)"
  aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp "s3://$ARTIFACT_BUCKET_NAME/_sites/$SITES_ARTIFACT" \
    "$tmp_sites_artifact"
else
  test -f "${sites_artifact_file}" || (echo "ERROR $0: No file found at ${sites_artifact_file}" && exit 1)
  echo "INFO $0: Using sites artifact file $sites_artifact_file"
  cp "$sites_artifact_file" "$tmp_sites_artifact"
fi
mkdir -p /etc/chillbox/sites/
tar x -z -f "$tmp_sites_artifact" -C /etc/chillbox/sites --strip-components 1 sites


# Most likely the nginx user has been added when the nginx package was
# installed.
if id -u nginx 2>&1 /dev/null; then
  echo "nginx user already added."
else
  echo "Adding nginx user."
  adduser -D -h /dev/null -H "nginx" || printf "Ignoring adduser error"
fi

export server_port="$CHILLBOX_SERVER_PORT"
current_working_dir=/usr/local/src
bin_dir="$(dirname "$0")"
sites="$(find /etc/chillbox/sites -type f -name '*.site.json')"
for site_json in $sites; do
  slugname="$(basename "$site_json" .site.json)"
  export slugname
  server_name="$(jq -r '.server_name' "$site_json")"
  export server_name
  echo "INFO $0: $slugname"
  echo "INFO $0: server_name=$server_name"
  cd "$current_working_dir"

  # no home, or password for user
  adduser -D -h /dev/null -H "$slugname" || printf "Ignoring adduser error"

  version="$(jq -r '.version' "$site_json")"
  export version

  deployed_version=""
  if [ -e "/srv/chillbox/$slugname/version.txt" ]; then
    deployed_version="$(cat "/srv/chillbox/$slugname/version.txt")"
  fi
  if [ "$version" = "$deployed_version" ]; then
    echo "INFO $0: Versions match for $slugname site."
    continue
  fi

  # A version.txt file is also added to the immutable bucket to allow skipping.
  "$bin_dir/upload-immutable-files-from-artifact.sh" "${slugname}" "${version}"

  tmp_artifact="$(mktemp)"
  export tmp_artifact
  aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp "s3://$ARTIFACT_BUCKET_NAME/${slugname}/artifacts/$slugname-$version.artifact.tar.gz" \
    "$tmp_artifact"


  export slugdir="$current_working_dir/$slugname"
  mkdir -p "$slugdir"
  chown -R "$slugname":"$slugname" "$slugdir"

  "$bin_dir/stop-site-services.sh" "${slugname}" "${slugdir}"

  "$bin_dir/site-init-nginx-service.sh" "${tmp_artifact}"

  # init services
  jq -c '.services // [] | .[]' "/etc/chillbox/sites/$slugname.site.json" \
    | while read -r service_obj; do
        test -n "${service_obj}" || continue

        cd "$current_working_dir"

        "$bin_dir/site-init-service-object.sh" "${service_obj}" "${tmp_artifact}" || echo "ERROR (ignored): Failed to init service object ${service_obj}"

      done
  rm -f "$tmp_artifact"

  # TODO Show errors if any service failed to start and output which services
  # have not started. Each service should not be dependant on other services
  # also being up, so no rollback of the deployment should happen. It is normal
  # for services that have a defined secrets config file to not fully start at
  # this point.

  echo "INFO $0: Finished setting up services for $site_json"

  eval "$(jq -r \
      '.env[] | "export " + .name + "=" + .value' "/etc/chillbox/sites/$slugname.site.json" \
        | envsubst "$(xargs < /etc/chillbox/env_names)")"

  site_env_names=$(jq -r '.env[] | "$" + .name' "/etc/chillbox/sites/$slugname.site.json" | xargs)
  site_env_names="$(xargs < /etc/chillbox/env_names) $site_env_names"

  # Set crontab
  tmpcrontab=$(mktemp)
  # TODO Should preserve any existing crontab entries?
  #      crontab -u $slugname -l || printf '' > $tmpcrontab
  # Append all crontab entries, use envsubst replacements
  jq -r '.crontab // [] | .[]' "/etc/chillbox/sites/$slugname.site.json"  \
    | envsubst "${site_env_names}" \
    | while read -r crontab_entry; do
        test -n "${crontab_entry}" || continue
        echo "${crontab_entry}" >> "$tmpcrontab"
      done
  crontab -u "$slugname" - < "$tmpcrontab"
  rm -f "$tmpcrontab"

  cd "$slugdir"
  # install site root dir
  mkdir -p "$slugdir/nginx/root"
  rm -rf "/srv/$slugname"
  mkdir -p "/srv/$slugname"
  mv "$slugdir/nginx/root" "/srv/$slugname/"
  chown -R nginx "/srv/$slugname/"
  mkdir -p "/var/log/nginx/"
  rm -rf "/var/log/nginx/$slugname/"
  mkdir -p "/var/log/nginx/$slugname/"
  chown -R nginx "/var/log/nginx/$slugname/"
  # Install nginx templates that start with slugname
  mkdir -p /etc/chillbox/templates/
  find "$slugdir/nginx/templates/" -name "$slugname*.nginx.conf.template" -exec mv {} /etc/chillbox/templates/ \;
  rm -rf "$slugdir/nginx"
  # Set version
  mkdir -p "/srv/chillbox/$slugname"
  chown -R nginx "/srv/chillbox/$slugname/"
  echo "$version" > "/srv/chillbox/$slugname/version.txt"

done
