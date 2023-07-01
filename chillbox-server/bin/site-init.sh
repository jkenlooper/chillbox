#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

chillbox_owner="$(cat /var/lib/chillbox/owner)"


export SITES_ARTIFACT="${SITES_ARTIFACT}"
if [ -z "${sites_artifact_file}" ]; then
  test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: SITES_ARTIFACT variable is empty" && exit 1)
  echo "INFO $script_name: Using SITES_ARTIFACT '${SITES_ARTIFACT}'"
fi
sites_artifact_file=${1:-"/var/lib/chillbox/sites/_sites/$SITES_ARTIFACT"}

export S3_ENDPOINT_URL="${S3_ENDPOINT_URL}"
test -n "${S3_ENDPOINT_URL}" || (echo "ERROR $script_name: S3_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $script_name: Using S3_ENDPOINT_URL '${S3_ENDPOINT_URL}'"

test -n "$AWS_PROFILE" || (echo "ERROR $script_name: No AWS_PROFILE set." && exit 1)

export CHILLBOX_SERVER_PORT="${CHILLBOX_SERVER_PORT}"
test -n "${CHILLBOX_SERVER_PORT}" || (echo "ERROR $script_name: CHILLBOX_SERVER_PORT variable is empty" && exit 1)
echo "INFO $script_name: Using CHILLBOX_SERVER_PORT '${CHILLBOX_SERVER_PORT}'"

export CHILLBOX_SUBNET="${CHILLBOX_SUBNET}"
test -n "${CHILLBOX_SUBNET}" || (echo "ERROR $script_name: CHILLBOX_SUBNET variable is empty" && exit 1)
echo "INFO $script_name: Using CHILLBOX_SUBNET '${CHILLBOX_SUBNET}'"

echo "INFO $script_name: Running site init"


tmp_sites_artifact="$(mktemp)"

cleanup() {
  echo ""
  rm -f "$tmp_sites_artifact"
}
trap cleanup EXIT

# TODO: make a backup directory of previous sites and then compare new sites to
# find any sites that should be deleted.
test -f "${sites_artifact_file}" || (echo "ERROR $script_name: No file found at ${sites_artifact_file}" && exit 1)
echo "INFO $script_name: Using sites artifact file $sites_artifact_file"
mkdir -p /etc/chillbox/sites/
tar x -z -f "$sites_artifact_file" -C /etc/chillbox/sites --strip-components 1 sites

# Most likely the nginx user has been added when the nginx package was
# installed.
if id -u nginx; then
  echo "INFO $script_name: nginx user already added."
else
  echo "INFO $script_name: Adding nginx user."
  adduser -D -h /dev/null -H "nginx" || echo "WARNING $script_name: Ignoring adduser error"
fi

export SERVER_PORT="$CHILLBOX_SERVER_PORT"
current_working_dir=/usr/local/src
bin_dir="$(dirname "$0")"
sites="$(find /etc/chillbox/sites -type f -name '*.site.json')"
for site_json in $sites; do
  SLUGNAME="$(basename "$site_json" .site.json)"
  export SLUGNAME
  SERVER_NAME="$(jq -r '.server_name' "$site_json")"
  export SERVER_NAME
  echo "INFO $script_name: $SLUGNAME"
  echo "INFO $script_name: SERVER_NAME=$SERVER_NAME"

  # TODO cd is needed?
  cd "$current_working_dir"

  # The $SLUGNAME user will have no home directory, or password.
  #
  # If a $SLUGNAME user would need a home directory; it would be for having
  # access to s3 bucket or potentially other services. A safer alternative would
  # be to set s3 access keys for only the service that requires it instead of
  # just relying on a /home/$SLUGNAME/.aws/credentials file. The s3 access keys
  # should be set in the secrets file that the app uses.
  if id -u "$SLUGNAME"; then
    echo "INFO $script_name: $SLUGNAME user already added."
  else
    echo "INFO $script_name: Adding $SLUGNAME user."
    adduser -D -h /dev/null -H "$SLUGNAME" || echo "WARNING $script_name: Ignoring adduser error"
  fi

  # TODO Check if there are any newer secrets in the s3 bucket for the site.
  # If there are newer secrets; delete the version.txt file.

  VERSION="$(jq -r '.version' "$site_json")"
  export VERSION

  mkdir -p /srv/chillbox/$SLUGNAME/
  deployed_version=""
  if [ -e "/srv/chillbox/$SLUGNAME/version.txt" ]; then
    deployed_version="$(cat "/srv/chillbox/$SLUGNAME/version.txt")"
  fi
  if [ "$VERSION" = "$deployed_version" ]; then
    echo "INFO $script_name: Versions match for $SLUGNAME site."
    if [ -s "/srv/chillbox/$SLUGNAME/tainted.txt" ]; then
      echo "INFO: Last site-init of $SLUGNAME version $VERSION is tainted."
    else
      continue
    fi
  fi
  # Start with a fresh run, so remove tainted.txt
  rm -f "/srv/chillbox/$SLUGNAME/tainted.txt"

  # A version.txt file is also added to the immutable bucket to allow skipping.
  "$bin_dir/upload-immutable-files-from-artifact.sh" "${SLUGNAME}" "${VERSION}"

  artifact="/var/lib/chillbox/sites/${SLUGNAME}/artifacts/$SLUGNAME-$VERSION.artifact.tar.gz"

  slugdir="$current_working_dir/$SLUGNAME"
  mkdir -p "$slugdir"
  chown -R "$SLUGNAME":"$SLUGNAME" "$slugdir"

  "$bin_dir/stop-site-services.sh" "${SLUGNAME}" "${slugdir}"

  "$bin_dir/site-init-nginx-service.sh" "${artifact}" "${slugdir}"

  "$bin_dir/site-init-redis.sh" "${artifact}" "${slugdir}" \
    || (echo "ERROR (ignored): Failed to init redis instance for ${SLUGNAME}" && echo "Failed site-init-redis.sh" >> "/srv/chillbox/$SLUGNAME/tainted.txt")

  # init workers
  jq -c '.workers // [] | .[]' "/etc/chillbox/sites/$SLUGNAME.site.json" \
    | while read -r worker_obj; do
        test -n "${worker_obj}" || continue

        # TODO cd is needed?
        cd "$current_working_dir"

        worker_name=""
        eval "$(echo "$worker_obj" | jq -r '@sh "
          worker_name=\(.name)
          "')"

        # TODO create a tmp json file of $worker_obj and pass that instead.
        "$bin_dir/site-init-worker-object.sh" "${worker_obj}" "${artifact}" "${slugdir}" \
          || (echo "ERROR (ignored): Failed to init worker object ${worker_name}" && echo "Failed site-init-worker-object.sh for $worker_name" >> "/srv/chillbox/$SLUGNAME/tainted.txt")

      done

  # init services
  jq -c '.services // [] | .[]' "/etc/chillbox/sites/$SLUGNAME.site.json" \
    | while read -r service_obj; do
        test -n "${service_obj}" || continue

        # TODO cd is needed?
        cd "$current_working_dir"

        service_name=""
        eval "$(echo "$service_obj" | jq -r '@sh "
          service_name=\(.name)
          "')"

        # TODO create a tmp json file of $service_obj and pass that instead.
        "$bin_dir/site-init-service-object.sh" "${service_obj}" "${artifact}" "${slugdir}" \
          || (echo "ERROR (ignored): Failed to init service object ${service_name}" && echo "Failed site-init-service-object.sh for $service_name" >> "/srv/chillbox/$SLUGNAME/tainted.txt")

      done

  # Show errors if any service or worker failed to start. Each service or worker
  # should not be dependent on other services or workers also being up, so no
  # rollback of the deployment should happen. It is normal for services or
  # workers that have a defined secrets config file to not fully start at this
  # point.
  if [ -s "/srv/chillbox/$SLUGNAME/tainted.txt" ]; then
    echo "ERROR: Failed to init:"
    cat "/srv/chillbox/$SLUGNAME/tainted.txt"
    echo ""
  fi

  echo "INFO $script_name: Finished setting up services and workers for $site_json"

  # Set crontab
  tmpcrontab=$(mktemp)
  # TODO Should preserve any existing crontab entries?
  #      crontab -u $SLUGNAME -l || printf '' > $tmpcrontab
  # Append all crontab entries, use envsubst replacements

  jq -r '.crontab // [] | .[]' "/etc/chillbox/sites/$SLUGNAME.site.json"  \
    | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json" \
    | while read -r crontab_entry; do
        test -n "${crontab_entry}" || continue
        echo "${crontab_entry}" >> "$tmpcrontab"
      done

  crontab -u "$SLUGNAME" - < "$tmpcrontab"
  rm -f "$tmpcrontab"

  cd "$slugdir"
  # install site root dir
  mkdir -p "$slugdir/nginx/root"
  rm -rf "/srv/$SLUGNAME"
  mkdir -p "/srv/$SLUGNAME"
  mv "$slugdir/nginx/root" "/srv/$SLUGNAME/"
  chown -R nginx "/srv/$SLUGNAME/"
  mkdir -p "/var/log/nginx/"
  rm -rf "/var/log/nginx/$SLUGNAME/"
  mkdir -p "/var/log/nginx/$SLUGNAME/"
  chown -R nginx "/var/log/nginx/$SLUGNAME/"
  # Install nginx templates that start with SLUGNAME
  mkdir -p /etc/chillbox/nginx/templates/
  find "$slugdir/nginx/templates/" -name "$SLUGNAME*.nginx.conf.template" -exec mv {} /etc/chillbox/nginx/templates/ \;
  rm -rf "$slugdir/nginx"
  # Set version
  mkdir -p "/srv/chillbox/$SLUGNAME"
  chown -R nginx "/srv/chillbox/$SLUGNAME/"
  echo "$VERSION" > "/srv/chillbox/$SLUGNAME/version.txt"

done
