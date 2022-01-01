#!/usr/bin/env sh

# download new sites/*site.json files from s3
# Check version on each and skip if currently deployed
# Stop and remove if not existing
# Create new ones
# Update to new versions

# TODO All the site.json is stored in a separate git repo

# TODO Add an endpoint to chillbox nginx that will trigger the update.sh script.
# Create a webhook on the site.json repo that triggers the chillbox endpoint to
# do the update.

set -o errexit

export IMMUTABLE_BUCKET_NAME="chillboximmutable"
export ARTIFACT_BUCKET_NAME="chillboxartifact"
export S3_ARTIFACT_ENDPOINT_URL=http://10.0.0.145:9000
export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
export SITES_ARTIFACT=chill-box-main.tar.gz

aws configure set default.s3.max_concurrent_requests 1

tmp_sites_artifact=$(mktemp)
aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp s3://$ARTIFACT_BUCKET_NAME/_sites/$SITES_ARTIFACT \
  $tmp_sites_artifact
mkdir -p /etc/chillbox/sites/
tar x -z -f $tmp_sites_artifact -C /etc/chillbox/sites --strip-components 1 sites

echo "export CHILLBOX_SERVER_NAME=$CHILLBOX_SERVER_NAME" > /etc/chillbox/site_env_vars
echo '$CHILLBOX_SERVER_NAME' > /etc/chillbox/site_env_names

mkdir -p /usr/local/src/
cd /usr/local/src/

current_working_dir=/usr/local/src
sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#/etc/chillbox/sites/}
  export slugname
  export server_name="$slugname.test"
  echo $slugname
  export version="$(jq -r '.version' $site_json)"
  deployed_version=""
  if [ -e /srv/chillbox/$slugname/version.txt ]; then
    deployed_version=$(cat /srv/chillbox/$slugname/version.txt)
  fi
  if [ "$version" = "$deployed_version" ]; then
    echo "Versions match for $slugname site."
    continue
  fi
  cd $current_working_dir

  # no home, or password for user
  adduser -D -h /dev/null -H "$slugname" || printf "Ignoring adduser error"

  jq -r \
    '.env[] | "export " + .name + "=" + .value' /etc/chillbox/sites/$slugname.site.json \
      | envsubst '$S3_ENDPOINT_URL $IMMUTABLE_BUCKET_NAME $slugname $version $server_name' >> /etc/chillbox/site_env_vars
  jq -r '.env[] | "$" + .name' /etc/chillbox/sites/$slugname.site.json | xargs >> /etc/chillbox/site_env_names


  tmp_artifact=$(mktemp)
  aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
    $tmp_artifact

  rc-service chill-$slugname status
  status=$?
  if [ "$status" -eq "0" ]; then
    rc-service chill-$slugname stop || printf "Ignoring"
    rc-update del chill-$slugname default || printf "Ignoring"
    rm -rf /usr/local/src/$slugname || printf "Ignoring"
    rm -f /etc/init.d/chill-$slugname || printf "Ignoring"
    rm -rf /etc/services.d/chill-$slugname
  fi

  tar x -z -f $tmp_artifact $slugname
  rm $tmp_artifact
  slugdir=$current_working_dir/$slugname
  chown -R $slugname:$slugname $slugdir

  # init chill
  cd $slugdir/chill
  su -p -s /bin/sh $slugname -c 'chill initdb'
  su -p -s /bin/sh $slugname -c 'chill load --yaml chill-data.yaml'

  if [ "$(jq -r '.freeze // false' /etc/chillbox/sites/$slugname.site.json)" = "true" ]; then
    echo 'freeze';
    rm -rf /etc/services.d/chill-$slugname
    rc-service chill-$slugname stop || printf ""
    rc-update delete chill-$slugname default || printf ""
    jq -r \
      '.chill_env[] | "export " + .name + "=" + .value' \
        /etc/chillbox/sites/$slugname.site.json \
        | envsubst '$S3_ENDPOINT_URL $IMMUTABLE_BUCKET_NAME $slugname $version $server_name' \
          > .env
    chown $slugname:$slugname .env
    source .env
    su -p -s /bin/sh $slugname -c 'chill freeze'
  else
    echo 'dynamic';
    cat <<PURR > /etc/init.d/chill-$slugname
#!/sbin/openrc-run
name="chill-$slugname"
description="chill-$slugname"
user="$slugname"
group="$slugname"
supervisor=s6
s6_service_path=/etc/services.d/chill-$slugname
depend() {
  need s6-svscan net localmount
  after firewall
}
PURR
    chmod +x /etc/init.d/chill-$slugname

    mkdir -p /etc/services.d/chill-$slugname

    cat <<MEOW > /etc/services.d/chill-$slugname/run
#!/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/chill
MEOW
    jq -r \
      '.chill_env[] | "s6-env " + .name + "=" + .value' \
        /etc/chillbox/sites/$slugname.site.json \
        | envsubst '$S3_ENDPOINT_URL $IMMUTABLE_BUCKET_NAME $slugname $version $server_name' \
          >> /etc/services.d/chill-$slugname/run
    cat <<MEOW >> /etc/services.d/chill-$slugname/run
chill serve
MEOW
    chmod +x /etc/services.d/chill-$slugname/run
    rc-update add chill-$slugname default
    rc-service chill-$slugname stop || printf ""
    rc-service chill-$slugname start
  fi

  cd $slugdir
  # install site root dir
  mkdir -p $slugdir/nginx/root
  rm -rf /srv/$slugname
  mkdir -p /srv/$slugname
  mv $slugdir/nginx/root /srv/$slugname/
  chown -R nginx:nginx /srv/$slugname/
  mkdir -p /var/log/nginx/
  rm -rf /var/log/nginx/$slugname/
  mkdir -p /var/log/nginx/$slugname/
  chown -R nginx:nginx /var/log/nginx/$slugname/
  # Install nginx templates that start with slugname
  mv $slugdir/nginx/templates/$slugname*.nginx.conf.template /etc/chillbox/templates/
  rm -rf $slugdir/nginx
  # Set version
  mkdir -p /srv/chillbox/$slugname
  chown -R nginx:nginx /srv/chillbox/$slugname/
  echo "$version" > /srv/chillbox/$slugname/version.txt

  source /etc/chillbox/site_env_vars
  for template_path in /etc/chillbox/templates/$slugname*.nginx.conf.template; do
    template_file=$(basename $template_path)
    envsubst "$(cat /etc/chillbox/site_env_names)" < $template_path > /etc/nginx/conf.d/${template_file%.template}
  done
  chown -R nginx:nginx /etc/nginx/conf.d/
  nginx -s reload
done
