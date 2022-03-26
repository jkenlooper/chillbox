#!/usr/bin/env sh

set -o errexit


export S3_ARTIFACT_ENDPOINT_URL=${S3_ARTIFACT_ENDPOINT_URL}
test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

export ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

export SITES_ARTIFACT=${SITES_ARTIFACT}
test -n "${SITES_ARTIFACT}" || (echo "ERROR $0: SITES_ARTIFACT variable is empty" && exit 1)
echo "INFO $0: Using SITES_ARTIFACT '${SITES_ARTIFACT}'"

export CHILLBOX_SERVER_PORT=${CHILLBOX_SERVER_PORT}
test -n "${CHILLBOX_SERVER_PORT}" || (echo "ERROR $0: CHILLBOX_SERVER_PORT variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_SERVER_PORT '${CHILLBOX_SERVER_PORT}'"

echo "INFO $0: Running site init"


# TODO: make a backup directory of previous sites and then compare new sites to
# find any sites that should be deleted. This would only be applicable to server
# version; not docker version.
tmp_sites_artifact=$(mktemp)
aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp s3://$ARTIFACT_BUCKET_NAME/_sites/$SITES_ARTIFACT \
  $tmp_sites_artifact
mkdir -p /etc/chillbox/sites/
tar x -z -f $tmp_sites_artifact -C /etc/chillbox/sites --strip-components 1 sites

export server_port=$CHILLBOX_SERVER_PORT
current_working_dir=/usr/local/src
sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#/etc/chillbox/sites/}
  export slugname
  export server_name="$slugname.test"
  echo "$slugname"
  echo "$server_name"
  cd $current_working_dir

  # no home, or password for user
  adduser -D -h /dev/null -H "$slugname" || printf "Ignoring adduser error"

  export version="$(jq -r '.version' $site_json)"

  deployed_version=""
  if [ -e /srv/chillbox/$slugname/version.txt ]; then
    deployed_version=$(cat /srv/chillbox/$slugname/version.txt)
  fi
  if [ "$version" = "$deployed_version" ]; then
    echo "Versions match for $slugname site."
    continue
  fi

  export tmp_artifact=$(mktemp)
  aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
    $tmp_artifact
  export slugdir=$current_working_dir/$slugname
  mkdir -p $slugdir
  chown -R $slugname:$slugname $slugdir

  # Stop all services in the $slugname directory and make backups
  find $slugname -depth -mindepth 1 -maxdepth 1 -type f -name '*.service_handler.json' \
    | while read -r existing_service_handler; do
      echo "Stopping existing service handler: $existing_service_handler"
      eval "$(jq -r '@sh "
      service_name=\(.name)
      service_lang_template=\(.lang)
      service_handler=\(.handler)
      service_secrets_config=\(.secrets_config)
      "' $existing_service_handler)"
      rc-service ${slugname}-${service_name} stop || printf "Ignoring"
      rc-update delete ${slugname}-${service_name} default || printf "Ignoring"
      rm -f /etc/init.d/${slugname}-${service_name} || printf "Ignoring"
      rm -rf /etc/services.d/${slugname}-${service_name} || printf "Ignoring"

      rm -rf $slugname/${service_handler}.bak.tar.gz
      rm -rf $slugname/${service_handler}.service_handler.json.bak
      rm -rf /var/lib/${slugname}/secrets/${service_secrets_config}.bak
      mv $slugname/${service_handler}.service_handler.json $slugname/${service_handler}.service_handler.json.bak
      test -e $slugname/${service_handler} \
        && tar c -f $slugname/${service_handler}.bak.tar.gz $slugname/${service_handler}
      test -n "$service_secrets_config" -a -e /var/lib/${slugname}/secrets/${service_secrets_config} \
        && mv /var/lib/${slugname}/secrets/${service_secrets_config} /var/lib/${slugname}/secrets/${service_secrets_config}.bak
  done

  # TODO Set nginx server for this $slugname to maintenance
  # Extract just the nginx directory from the tmp_artifact
  rm -rf $slugname/nginx.bak.tar.gz
  test -e $slugname/nginx \
    && tar c -f $slugname/nginx.bak.tar.gz $slugname/nginx
  rm -rf $slugname/nginx
  tar x -z -f $tmp_artifact $slugname/nginx
  chown -R $slugname:$slugname $slugdir
  echo "Extracted nginx service for $slugname"
  ls -al $slugname/

  # init services
  jq -c '.services // [] | .[]' /etc/chillbox/sites/$slugname.site.json \
    | while read -r service_obj; do
        test -n "${service_obj}" || continue

        cd $current_working_dir

        $(dirname $0)/site-init-service-object.sh "${service_obj}"

      done

  # TODO Handle errors if any service failed to start and rollback to the backup.

  echo "Finished setting up services for $site_json"

  eval $(jq -r \
      '.env[] | "export " + .name + "=" + .value' /etc/chillbox/sites/$slugname.site.json \
        | envsubst "$(cat /etc/chillbox/env_names | xargs)")

  site_env_names=$(jq -r '.env[] | "$" + .name' /etc/chillbox/sites/$slugname.site.json | xargs)
  site_env_names="$(cat /etc/chillbox/env_names | xargs) $site_env_names"

  # Set crontab
  tmpcrontab=$(mktemp)
  # TODO Should preserve any existing crontab entries?
  #      crontab -u $slugname -l || printf '' > $tmpcrontab
  # Append all crontab entries, use envsubst replacements
  jq -r '.crontab // [] | .[]' /etc/chillbox/sites/$slugname.site.json  \
    | envsubst "${site_env_names}" \
    | while read -r crontab_entry; do
        test -n "${crontab_entry}" || continue
        echo "${crontab_entry}" >> $tmpcrontab
      done
  cat $tmpcrontab | crontab -u $slugname -
  rm -f $tmpcrontab

  cd $slugdir
  # install site root dir
  mkdir -p $slugdir/nginx/root
  rm -rf /srv/$slugname
  mkdir -p /srv/$slugname
  mv $slugdir/nginx/root /srv/$slugname/
  chown -R nginx /srv/$slugname/
  mkdir -p /var/log/nginx/
  rm -rf /var/log/nginx/$slugname/
  mkdir -p /var/log/nginx/$slugname/
  chown -R nginx /var/log/nginx/$slugname/
  # Install nginx templates that start with slugname
  mv $slugdir/nginx/templates/$slugname*.nginx.conf.template /etc/chillbox/templates/
  rm -rf $slugdir/nginx
  # Set version
  mkdir -p /srv/chillbox/$slugname
  chown -R nginx /srv/chillbox/$slugname/
  echo "$version" > /srv/chillbox/$slugname/version.txt
done
