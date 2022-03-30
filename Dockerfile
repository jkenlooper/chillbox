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

ENV CHILLBOX_SERVER_NAME=localhost
ARG CHILLBOX_SERVER_PORT=80
ENV CHILLBOX_SERVER_PORT=$CHILLBOX_SERVER_PORT
ARG S3_ARTIFACT_ENDPOINT_URL
ARG S3_ENDPOINT_URL
ENV S3_ENDPOINT_URL=$S3_ENDPOINT_URL
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact
ARG SITES_ARTIFACT

## RUN AWS_CLI
COPY bin/install-aws-cli.sh /etc/chillbox/bin/
RUN <<AWS_CLI
apk update
/etc/chillbox/bin/install-aws-cli.sh
AWS_CLI

## COPY_chillbox_artifact
COPY templates /etc/chillbox/templates
COPY bin /etc/chillbox/bin

# TECH_EMAIL is used when registering with letsencrypt
ARG TECH_EMAIL=""
ARG ACME_SH_VERSION="3.0.1"
# Set LETS_ENCRYPT_SERVER variable to either 'letsencrypt_test' or 'letsencrypt'
ARG LETS_ENCRYPT_SERVER=""

## RUN_INSTALL_SCRIPTS
# TODO: switch to released chill version
#ARG PIP_CHILL="chill==0.9.0"
ARG PIP_CHILL="git+https://github.com/jkenlooper/chill.git@7ad7c87da8f3184d884403d86ecf70abf293039f#egg=chill"
RUN <<INSTALL_SCRIPTS
apk update
/etc/chillbox/bin/install-chill.sh $PIP_CHILL
/etc/chillbox/bin/install-service-dependencies.sh
SKIP_INSTALL_ACMESH="y" /etc/chillbox/bin/install-acme.sh
INSTALL_SCRIPTS

## RUN_CHILLBOX_ENV_NAMES
RUN /etc/chillbox/bin/create-env_names-file.sh

## WORKDIR /usr/local/src/
WORKDIR /usr/local/src/

## RUN SITE_INIT
RUN --mount=type=secret,id=awscredentials --mount=type=secret,id=site_secrets <<SITE_INIT

source /run/secrets/awscredentials

# Extract secrets to the /var/lib/
mkdir -p /var/lib
tar x -f /run/secrets/site_secrets -C /var/lib --strip-components=1

set -o errexit

/etc/chillbox/bin/site-init.sh

apk --purge del \
  gcc \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev
SITE_INIT


## COPY nginx conf and default
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.nginx.conf /etc/nginx/conf.d/default.conf


## RUN NGINX_CONF
RUN <<NGINX_CONF
/etc/chillbox/bin/init-nginx.sh
NGINX_CONF

## RUN DEV_USER
RUN <<DEV_USER
addgroup dev
adduser -G dev -D dev
chown dev /etc/chillbox/env_names
DEV_USER
# TODO: best practice is to not run a container as root user.
#USER dev

EXPOSE 80


#CMD ["nginx", "-g", "daemon off;"]
CMD ["./dev.sh"]
