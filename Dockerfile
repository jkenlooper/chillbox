# syntax=docker/dockerfile:1.3-labs

FROM alpine:3.15.0

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


ENV CHILLBOX_SERVER_NAME=localhost
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.nginx.conf /etc/nginx/conf.d/default.conf
COPY templates /etc/nginx/templates
# gettext includes envsubst
RUN <<NGINX_CONF
apk update
apk add gettext
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
for template_path in /etc/nginx/templates/*.nginx.conf.template; do
  template_file=$(basename $template_path)
  envsubst '$CHILLBOX_SERVER_NAME $S3_ENDPOINT_URL' < $template_path > /etc/nginx/conf.d/${template_file%.template}
done
chown -R nginx:nginx /etc/nginx/conf.d/
nginx -t
NGINX_CONF


ARG S3_ENDPOINT_URL
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact

ARG slugname="jengalaxyart"
WORKDIR /usr/local/src/
COPY sites/$slugname.site.json /tmp/
RUN --mount=type=secret,id=awscredentials <<SITE_INIT
source /run/secrets/awscredentials
echo "access key id $AWS_ACCESS_KEY_ID"
aws --version
export version="$(jq -r '.version' /tmp/$slugname.site.json)"
aws --endpoint-url "$S3_ENDPOINT_URL" \
  s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
  /tmp/
tar -xf /tmp/$slugname-$version.artifact.tar.gz
rm /tmp/$slugname-$version.artifact.tar.gz
rm /tmp/$slugname.site.json
cd $slugname/chill
chill initdb
chill load --yaml chill-data.yaml
mkdir -p /srv/chillbox/$slugname
chown -R nginx:nginx /srv/chillbox/$slugname/
echo "$version" > /srv/chillbox/$slugname/version.txt
SITE_INIT




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
