# syntax=docker/dockerfile:1.3.0-labs

FROM alpine:3.15.0@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300

LABEL org.opencontainers.image.authors="Jake Hickenlooper <jake@weboftomorrow.com>"

## s6-overlay
# https://github.com/just-containers/s6-overlay
ARG S6_OVERLAY_RELEASE=v2.2.0.3
ENV S6_OVERLAY_RELEASE=${S6_OVERLAY_RELEASE}
RUN <<S6_OVERLAY
apk update
apk add --no-cache \
  gnupg \
  gnupg-dirmngr
mkdir -p /tmp
wget -P /tmp/ \
   https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_RELEASE}/s6-overlay-amd64.tar.gz
wget -P /tmp/ \
   https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_RELEASE}/s6-overlay-amd64.tar.gz.sig
gpg --keyserver pgp.surfnet.nl --recv-keys 6101B2783B2FD161
gpg --verify /tmp/s6-overlay-amd64.tar.gz.sig /tmp/s6-overlay-amd64.tar.gz
tar xzf /tmp/s6-overlay-amd64.tar.gz -C /
rm -rf /tmp/s6-overlay-amd64.tar.gz /tmp/s6-overlay-amd64.tar.gz.sig
apk --purge del \
  gnupg \
  gnupg-dirmngr
S6_OVERLAY
ENTRYPOINT [ "/init" ]

## nginx
EXPOSE 80
RUN <<NGINX
apk update
apk add --no-cache \
  nginx
nginx -v
NGINX

## chill
# TODO: switch to released chill version
#ARG PIP_CHILL="chill==0.9.0"
ARG PIP_CHILL="git+https://github.com/jkenlooper/chill.git@develop#egg=chill"
RUN <<CHILL
apk update
apk add --no-cache \
  py3-pip \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  make \
  git \
  sqlite
ln -s /usr/bin/python3 /usr/bin/python
python --version
python -m pip install --disable-pip-version-check "$PIP_CHILL"
apk --purge del \
  gcc \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  make \
  git
chill --version
CHILL

## aws cli
RUN <<AWS_CLI
apk update
apk add --no-cache \
  jq \
  aws-cli
aws --version
AWS_CLI

# gettext includes envsubst
RUN <<SUPPORT_ENVSUBST
apk update
apk add gettext
SUPPORT_ENVSUBST

ENV CHILLBOX_SERVER_NAME=localhost
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.nginx.conf /etc/nginx/conf.d/default.conf
COPY templates /etc/chillbox/templates

ARG S3_ARTIFACT_ENDPOINT_URL
ARG S3_ENDPOINT_URL
ENV S3_ENDPOINT_URL=$S3_ENDPOINT_URL
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact
# TODO: This needs to be updated in order for any new sites to be added.
ARG SITES_ARTIFACT

RUN <<CHILLBOX
echo "export CHILLBOX_SERVER_NAME=$CHILLBOX_SERVER_NAME" > /etc/chillbox/site_env_vars
echo '$CHILLBOX_SERVER_NAME' > /etc/chillbox/site_env_names
CHILLBOX

WORKDIR /usr/local/src/
RUN --mount=type=secret,id=awscredentials <<SITE_INIT
apk update
apk add --no-cache \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev

source /run/secrets/awscredentials

set -v
set -o errexit

# TODO: make a backup directory of previous sites and then compare new sites to
# find any sites that should be deleted. This would only be applicable to server
# version; not docker version.
tmp_sites_artifact=$(mktemp)
aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp s3://$ARTIFACT_BUCKET_NAME/_sites/$SITES_ARTIFACT \
  $tmp_sites_artifact
mkdir -p /etc/chillbox/sites/
tar x -z -f $tmp_sites_artifact -C /etc/chillbox/sites --strip-components 1 sites

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

  aws --version
  export version="$(jq -r '.version' /etc/chillbox/sites/$slugname.site.json)"

  jq -r \
    '.env[] | "export " + .name + "=" + .value' /etc/chillbox/sites/$slugname.site.json \
      | envsubst '$S3_ENDPOINT_URL $IMMUTABLE_BUCKET_NAME $slugname $version $server_name' >> /etc/chillbox/site_env_vars
  jq -r '.env[] | "$" + .name' /etc/chillbox/sites/$slugname.site.json | xargs >> /etc/chillbox/site_env_names

  tmp_artifact=$(mktemp)
  aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
    $tmp_artifact
  tar x -z -f $tmp_artifact $slugname
  rm $tmp_artifact
  slugdir=$current_working_dir/$slugname
  chown -R $slugname:$slugname $slugdir

  # init chill
  cd $slugdir/chill
  echo $slugname
  su -p -s /bin/sh $slugname -c 'chill initdb'
  su -p -s /bin/sh $slugname -c 'chill load --yaml chill-data.yaml'


  if [ "$(jq -r '.freeze // false' /etc/chillbox/sites/$slugname.site.json)" = "true" ]; then
    echo 'freeze';
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
    mkdir -p /etc/services.d/chill-$slugname
    cat <<MEOW > /etc/services.d/chill-$slugname/run
#!/usr/bin/execlineb -P
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
  fi

  # init services
  jq -c '.services // [] | .[]' /etc/chillbox/sites/$slugname.site.json \
    | while read -r service_obj; do
        test -n "${service_obj}" || continue


        # Extract and set shell variables from JSON input
        eval "$(echo $service_obj | jq -r '@sh "
          service_name=\(.name)
          service_lang=\(.lang)
          service_handler=\(.handler)
          "')"

        cd $slugdir/${service_handler}

        # Create the Flask config.py from the environment field
        mkdir -p "/var/lib/${slugname}"
        chown -R $slugname:$slugname "/var/lib/${slugname}"
        echo $service_obj | jq -r '.environment // [] | .[] | .name + "=" + .value' \
          > "/var/lib/${slugname}/${service_name}.config.py"

        python -m venv .venv
        ./.venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt .

        # TODO: init_db only when first installing?
        ./.venv/bin/flask init-db


        cat <<PURR > /etc/services.d/{service_handler}-$slugname/run
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/${service_handler}
./.venv/bin/${service_name}
PURR

      done

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

apk --purge del \
  gcc \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev
SITE_INIT


RUN <<NGINX_CONF
mkdir -p /srv/chillbox
chown -R nginx /srv/chillbox/
mkdir -p /var/cache/nginx
chown -R nginx /var/cache/nginx
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/chillbox/
chown -R nginx /var/log/nginx/chillbox/
rm -rf /etc/nginx/conf.d/
mkdir -p /etc/nginx/conf.d/
chown -R nginx /etc/nginx/conf.d/
source /etc/chillbox/site_env_vars
for template_path in /etc/chillbox/templates/*.nginx.conf.template; do
  template_file=$(basename $template_path)
  envsubst "$(cat /etc/chillbox/site_env_names)" < $template_path > /etc/nginx/conf.d/${template_file%.template}
done
chown -R nginx /etc/nginx/conf.d/
NGINX_CONF

# TODO: best practice is to not run a container as root user.
RUN <<DEV_USER
addgroup dev
adduser -G dev -D dev
DEV_USER
#USER dev

CMD ["nginx", "-g", "daemon off;"]
