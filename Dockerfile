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

## RUN NGINX
EXPOSE 80
RUN <<NGINX
apk update
apk add --no-cache \
  nginx
nginx -v
NGINX

## RUN CHILL
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
pip install --upgrade pip
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

## RUN AWS_CLI
RUN <<AWS_CLI
apk update
apk add --no-cache \
  jq \
  aws-cli
aws --version
AWS_CLI

## RUN SUPPORT_ENVSUBST
RUN <<SUPPORT_ENVSUBST
apk update
# gettext includes envsubst
apk add gettext
SUPPORT_ENVSUBST

## RUN CHILLBOX_ENV_NAMES
RUN <<CHILLBOX_ENV_NAMES
mkdir -p /etc/chillbox
cat <<'ENV_NAMES' > /etc/chillbox/env_names
$CHILLBOX_SERVER_NAME
$S3_ENDPOINT_URL
$IMMUTABLE_BUCKET_NAME
$ARTIFACT_BUCKET_NAME
$slugname
$version
$server_name
ENV_NAMES
CHILLBOX_ENV_NAMES

## RUN SERVICES_DEPENDENCIES
RUN <<SERVICES_DEPENDENCIES
apk update
apk add --no-cache \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  zlib \
  openjpeg \
  libjpeg \
  tiff \
  freetype \
  fribidi \
  harfbuzz \
  jpeg \
  lcms2 \
  tcl \
  tk \
  freetype-dev \
  fribidi-dev \
  harfbuzz-dev \
  jpeg-dev \
  lcms2-dev \
  openjpeg-dev \
  tcl-dev \
  tiff-dev \
  tk-dev \
  zlib-dev
SERVICES_DEPENDENCIES

ENV CHILLBOX_SERVER_NAME=localhost
ARG S3_ARTIFACT_ENDPOINT_URL
ARG S3_ENDPOINT_URL
ENV S3_ENDPOINT_URL=$S3_ENDPOINT_URL
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact
ARG SITES_ARTIFACT

## COPY chillbox artifact
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.nginx.conf /etc/nginx/conf.d/default.conf
COPY templates /etc/chillbox/templates
COPY bin /etc/chillbox/bin

WORKDIR /usr/local/src/

## RUN SITE_INIT
RUN --mount=type=secret,id=awscredentials --mount=type=secret,id=site_secrets <<SITE_INIT

source /run/secrets/awscredentials

# Extract secrets to the /var/lib/
mkdir -p /var/lib
tar x -f /run/secrets/site_secrets -C /var/lib --strip-components=1

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

  tmp_artifact=$(mktemp)
  aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
    s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
    $tmp_artifact
  tar x -z -f $tmp_artifact $slugname
  rm $tmp_artifact
  slugdir=$current_working_dir/$slugname
  chown -R $slugname:$slugname $slugdir

  # init services
  jq -c '.services // [] | .[]' /etc/chillbox/sites/$slugname.site.json \
    | while read -r service_obj; do
        test -n "${service_obj}" || continue

        # Extract and set shell variables from JSON input
        eval "$(echo $service_obj | jq -r '@sh "
          service_name=\(.name)
          service_lang_template=\(.lang)
          service_handler=\(.handler)
          service_secrets_config=\(.secrets_config)
          "')"
        eval $(echo $service_obj | jq -r '.environment // [] | .[] | "export " + .name + "=\"" + .value + "\""' \
          | envsubst "$(cat /etc/chillbox/env_names | xargs)")

        cd $slugdir/${service_handler}
        if [ "${service_lang_template}" = "flask" ]; then

          mkdir -p "/var/lib/${slugname}/${service_handler}"
          chown -R $slugname:$slugname "/var/lib/${slugname}"

          python -m venv .venv
          ./.venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt .

          # TODO: init_db only when first installing?
          HOST=localhost \
          FLASK_ENV="development" \
          FLASK_INSTANCE_PATH="/var/lib/${slugname}/${service_handler}" \
          S3_ENDPOINT_URL=$S3_ARTIFACT_ENDPOINT_URL \
          SECRETS_CONFIG=/var/lib/${slugname}/secrets/${service_secrets_config} \
            ./.venv/bin/flask init-db

          chown -R $slugname:$slugname "/var/lib/${slugname}/"

          mkdir -p /etc/services.d/${slugname}-${service_name}
          cat <<PURR > /etc/services.d/${slugname}-${service_name}/run
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/${service_handler}
PURR
          echo $service_obj | jq -r '.environment // [] | .[] | "s6-env " + .name + "=\"" + .value + "\""' \
            | envsubst "$(cat /etc/chillbox/env_names | xargs)" \
            >> /etc/services.d/${slugname}-${service_name}/run
          cat <<PURR >> /etc/services.d/${slugname}-${service_name}/run
s6-env HOST=localhost \
s6-env FLASK_ENV=development
s6-env FLASK_INSTANCE_PATH="/var/lib/${slugname}/${service_handler}"
s6-env SECRETS_CONFIG=/var/lib/${slugname}/secrets/${service_secrets_config}
s6-env S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
s6-env ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
s6-env IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
./.venv/bin/start
PURR
        elif [ "${service_lang_template}" = "chill" ]; then

          # init chill
          su -p -s /bin/sh $slugname -c 'chill initdb'
          su -p -s /bin/sh $slugname -c 'chill load --yaml chill-data.yaml'

          if [ "${freeze}" = "true" ]; then
            echo 'freeze';
            su -p -s /bin/sh $slugname -c 'chill freeze'
          else
            echo 'dynamic';

            mkdir -p /etc/services.d/${slugname}-${service_name}

            cat <<MEOW > /etc/services.d/${slugname}-${service_name}/run
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/${service_handler}
MEOW
            echo $service_obj | jq -r '.environment // [] | .[] | "s6-env " + .name + "=\"" + .value + "\""' \
              | envsubst "$(cat /etc/chillbox/env_names | xargs)" \
              >> /etc/services.d/${slugname}-${service_name}/run
            cat <<PURR >> /etc/services.d/${slugname}-${service_name}/run
chill serve
PURR
          fi

        else
          echo "ERROR: The service 'lang' template: '${service_lang_template}' is not supported!"
          exit 12
        fi

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


## RUN NGINX_CONF
RUN <<NGINX_CONF

set -o errexit

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

cat <<'HISS' > reload-templates.sh
#!/usr/bin/env sh

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#/etc/chillbox/sites/}
  export slugname
  export server_name="$slugname.test"
  export version="$(jq -r '.version' $site_json)"

  eval $(jq -r \
      '.env[] | "export " + .name + "=" + .value' $site_json \
        | envsubst "$(cat /etc/chillbox/env_names | xargs)")

  site_env_names=$(jq -r '.env[] | "$" + .name' /etc/chillbox/sites/$slugname.site.json | xargs)
  site_env_names="$(cat /etc/chillbox/env_names | xargs) $site_env_names"

  template_path=/etc/chillbox/templates/$slugname.nginx.conf.template
  template_file=$(basename $template_path)
  envsubst "${site_env_names}" < $template_path > /etc/nginx/conf.d/${template_file%.template}
done

template_path=/etc/chillbox/templates/chillbox.nginx.conf.template
template_file=$(basename $template_path)
envsubst '$CHILLBOX_SERVER_NAME' < $template_path > /etc/nginx/conf.d/${template_file%.template}
HISS

cat <<'HISS' > dev.sh
#!/usr/bin/env sh

/usr/local/src/reload-templates.sh
nginx -t
nginx -g 'daemon off;'
HISS

chmod +x reload-templates.sh
/usr/local/src/reload-templates.sh

chmod +x dev.sh
chown -R nginx /etc/nginx/conf.d/
NGINX_CONF

## RUN DEV_USER
RUN <<DEV_USER
addgroup dev
adduser -G dev -D dev
chown dev /etc/chillbox/env_names
DEV_USER
# TODO: best practice is to not run a container as root user.
#USER dev

#CMD ["nginx", "-g", "daemon off;"]
CMD ["./dev.sh"]
