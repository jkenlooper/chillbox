# syntax=docker/dockerfile:1.3.0-labs

FROM alpine:3.15.0@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300

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
COPY sites /etc/chillbox/sites

ARG S3_ARTIFACT_ENDPOINT_URL
ARG S3_ENDPOINT_URL
ENV S3_ENDPOINT_URL=$S3_ENDPOINT_URL
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact

RUN <<CHILLBOX
echo "export CHILLBOX_SERVER_NAME=$CHILLBOX_SERVER_NAME" >> /etc/chillbox/site_env_vars
echo '$CHILLBOX_SERVER_NAME' >> /etc/chillbox/site_env_names
CHILLBOX

ARG slugname="jengalaxyart"
ARG server_name="jengalaxyart.test"
WORKDIR /usr/local/src/
RUN --mount=type=secret,id=awscredentials <<SITE_INIT
# no home, password, or shell for user
adduser -D -h /dev/null -H -s /dev/null $slugname

source /run/secrets/awscredentials
echo "access key id $AWS_ACCESS_KEY_ID"
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
tar -x -f $tmp_artifact
rm $tmp_artifact
slugdir=$PWD/$slugname
chown -R $slugname:$slugname $slugdir

# init chill
cd $slugdir/chill
echo $slugname
su -p -s /bin/sh $slugname -c 'chill initdb'
su -p -s /bin/sh $slugname -c 'chill load --yaml chill-data.yaml'

mkdir -p /etc/services.d/chill-$slugname

cat <<MEOW > /etc/services.d/chill-$slugname/run
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/chill
s6-env CHILL_HOST=localhost
s6-env CHILL_PORT=5000
s6-env CHILL_MEDIA_PATH=/media/
s6-env CHILL_THEME_STATIC_PATH=/theme/$version/
s6-env CHILL_DESIGN_TOKENS_HOST=/design-tokens/$version/
chill serve
MEOW

cd $slugdir
# install site root dir
mkdir -p $slugdir/nginx/root
mkdir -p /srv/$slugname
mv $slugdir/nginx/root /srv/$slugname/
chown -R nginx /srv/$slugname/
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/$slugname/
chown -R nginx /var/log/nginx/$slugname/
# Install nginx templates that start with slugname
mv $slugdir/nginx/templates/$slugname*.nginx.conf.template /etc/chillbox/templates/
rm -rf $slugdir/nginx
# Set version
mkdir -p /srv/chillbox/$slugname
chown -R nginx /srv/chillbox/$slugname/
echo "$version" > /srv/chillbox/$slugname/version.txt
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


## for each site
# s3 cp the artifact
#
## Other apps that will run as services
#COPY services/example /etc/services.d/example

# fetch artifact file for each chill app

# On remote chillbox host (only read access to S3)
# - Download artifact tar.gz from S3
# - Expand to new directory for the version
# - chill init, load yaml
# - add and enable, start the systemd service for new version
# - stage the new version by updating NGINX environment variables
# - run integration tests on staged version
# - promote the staged version to production by updating NGINX environment variables
# - remove old version
# - write version to /srv/chillbox/$slugname/version.txt

# On local
# - Delete old immutable versioned path on S3

RUN <<DEV_USER
addgroup dev
adduser -G dev -D dev
DEV_USER
#USER dev

CMD ["nginx", "-g", "daemon off;"]
