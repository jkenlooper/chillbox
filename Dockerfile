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
WORKDIR /usr/local/src/chill-venv
COPY requirements.txt ./
RUN <<CHILL
apk update
apk add --no-cache \
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
python -m venv .
/usr/local/src/chill-venv/bin/pip install --upgrade pip wheel
/usr/local/src/chill-venv/bin/pip install --disable-pip-version-check -r requirements.txt
ln -s /usr/local/src/chill-venv/bin/chill /usr/local/bin/chill
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
COPY templates /etc/nginx/templates

ARG S3_ARTIFACT_ENDPOINT_URL
ARG S3_ENDPOINT_URL
ENV S3_ENDPOINT_URL=$S3_ENDPOINT_URL
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact


RUN <<CHILLBOX
echo "export CHILLBOX_SERVER_NAME=$CHILLBOX_SERVER_NAME" >> /tmp/site_env_vars
echo '$CHILLBOX_SERVER_NAME' >> /tmp/site_env_names
CHILLBOX

ARG slugname="jengalaxyart"
ARG server_name="jengalaxyart.test"
#http://localhost:9000/chillboximmutable/jengalaxyart/0.3.0-alpha.1/client-side-public/main.css
WORKDIR /usr/local/src/
COPY sites/$slugname.site.json /tmp/
RUN --mount=type=secret,id=awscredentials <<SITE_INIT
source /run/secrets/awscredentials
echo "access key id $AWS_ACCESS_KEY_ID"
aws --version
export version="$(jq -r '.version' /tmp/$slugname.site.json)"

jq -r \
  '.env[] | "export " + .name + "=" + .value' /tmp/$slugname.site.json \
    | envsubst '$S3_ENDPOINT_URL $IMMUTABLE_BUCKET_NAME $slugname $version' >> /tmp/site_env_vars
jq -r '.env[] | "$" + .name' /tmp/$slugname.site.json | xargs >> /tmp/site_env_names
echo /tmp/site_env_vars
cat /tmp/site_env_vars
echo /tmp/site_env_names
cat /tmp/site_env_names


aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
  /tmp/
tar -xf /tmp/$slugname-$version.artifact.tar.gz
#rm /tmp/$slugname-$version.artifact.tar.gz
#rm /tmp/$slugname.site.json
slugdir=$PWD/$slugname
# init chill
cd $slugdir/chill
chill initdb
chill load --yaml chill-data.yaml
mkdir -p /etc/services.d/chill-$slugname

cat <<MEOW > /etc/services.d/chill-$slugname/run
#!/usr/bin/execlineb -P
cd $slugdir/chill
s6-env CHILL_HOST=localhost
s6-env CHILL_PORT=5000
s6-env CHILL_MEDIA_PATH=/media/
s6-env CHILL_THEME_STATIC_PATH=/theme/$version/
s6-env CHILL_DESIGN_TOKENS_HOST=/design-tokens/$version/
/usr/local/bin/chill serve
MEOW

cd $slugdir
# install site root dir
mkdir -p $slugdir/nginx/root
mkdir -p /srv/$slugname
mv $slugdir/nginx/root /srv/$slugname/
chown -R nginx:ngnix /srv/$slugname/
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/$slugname/
chown -R nginx:nginx /var/log/nginx/$slugname/
# Install nginx templates that start with slugname
mv $slugdir/nginx/templates/$slugname*.nginx.conf.template /etc/nginx/templates/
rm -rf $slugdir/nginx
# Set version
mkdir -p /srv/chillbox/$slugname
chown -R nginx:nginx /srv/chillbox/$slugname/
echo "$version" > /srv/chillbox/$slugname/version.txt
SITE_INIT


RUN <<NGINX_CONF
chown -R nginx:nginx /etc/nginx/templates/
mkdir -p /srv/chillbox
chown -R nginx:nginx /srv/chillbox/
mkdir -p /var/cache/nginx
chown -R nginx:nginx /var/cache/nginx
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/chillbox/
chown -R nginx:nginx /var/log/nginx/chillbox/
rm -rf /etc/nginx/conf.d/
mkdir -p /etc/nginx/conf.d/
chown -R nginx:nginx /etc/nginx/conf.d/
source /tmp/site_env_vars
for template_path in /etc/nginx/templates/*.nginx.conf.template; do
  template_file=$(basename $template_path)
  envsubst "$(cat /tmp/site_env_names)" < $template_path > /etc/nginx/conf.d/${template_file%.template}
done
chown -R nginx:nginx /etc/nginx/conf.d/
# No test when building
#nginx -t
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

CMD ["nginx", "-g", "daemon off;"]
