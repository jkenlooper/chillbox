# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-07-12" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.15.4
# docker image ls --digests alpine
FROM alpine:3.15.4@sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454

## s6-overlay
# https://github.com/just-containers/s6-overlay
# UPKEEP due: "2022-02-01" label: "Alpine Linux just-containers/s6-overlay" interval: "+3 months"
#        Update to v3 will require changes other then a version bump.
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

## RUN_SETUP
RUN <<SETUP
apk update
apk add sed attr grep coreutils
apk add mandoc man-pages
SETUP

## COPY_chillbox_artifact
COPY templates /etc/chillbox/templates
COPY bin /etc/chillbox/bin

## RUN_INSTALL_SCRIPTS
# TODO: switch to released chill version
#ARG PIP_CHILL="chill==0.9.0"
ARG PIP_CHILL="git+https://github.com/jkenlooper/chill.git@7ad7c87da8f3184d884403d86ecf70abf293039f#egg=chill"
# TECH_EMAIL is used when registering with letsencrypt
ARG TECH_EMAIL="local@example.com"
ENV TECH_EMAIL="$TECH_EMAIL"
ARG LETS_ENCRYPT_SERVER="letsencrypt_test"
ENV LETS_ENCRYPT_SERVER="$LETS_ENCRYPT_SERVER"
RUN <<INSTALL_SCRIPTS
apk update
/etc/chillbox/bin/install-aws-cli.sh
/etc/chillbox/bin/install-chill.sh $PIP_CHILL
/etc/chillbox/bin/install-service-dependencies.sh
SKIP_INSTALL_ACMESH="y" /etc/chillbox/bin/install-acme.sh
INSTALL_SCRIPTS


## RUN_CHILLBOX_ENV_NAMES
RUN /etc/chillbox/bin/create-env_names-file.sh

## WORKDIR /usr/local/src/
WORKDIR /usr/local/src/

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

cat <<'HERE' > dev.sh
#!/usr/bin/env sh

set -o errexit

# The site-init.sh and other scripts it calls will use the aws-cli. These aws
# commands should only interact with the local s3 object storage.
aws configure import --csv "file:///var/lib/chillbox-shared-secrets/chillbox-minio/local-chillbox.credentials.csv"
export AWS_PROFILE="local-chillbox"

/etc/chillbox/bin/site-init.sh

/etc/chillbox/bin/reload-templates.sh
nginx -t
nginx -g 'daemon off;'
HERE
chmod +x dev.sh
DEV_USER

EXPOSE 80

# Set environment and build-args for create-env_names-file.sh to use
ENV CHILLBOX_SERVER_NAME=localhost
ENV CHILLBOX_SERVER_PORT=80
#ARG S3_ENDPOINT_URL
ENV S3_ENDPOINT_URL=""
#ARG S3_ARTIFACT_ENDPOINT_URL
ENV S3_ARTIFACT_ENDPOINT_URL=""
ENV IMMUTABLE_BUCKET_NAME=""
ENV ARTIFACT_BUCKET_NAME=""
#ARG SITES_ARTIFACT
ENV SITES_ARTIFACT=""



# TODO: best practice is to not run a container as root user.
#USER dev

CMD ["./dev.sh"]
