#!/usr/bin/env sh

# TODO Add an endpoint to chillbox nginx that will trigger the update.sh script.
# Create a webhook on the site.json repo that triggers the chillbox endpoint to
# do the update.

set -o errexit

source /home/dev/.env

aws configure set default.s3.max_concurrent_requests 1

## WORKDIR /usr/local/src/
mkdir -p /usr/local/src/
cd /usr/local/src/

## RUN SITE_INIT

/etc/chillbox/bin/site-init.sh

# TODO RUN NGINX_CONF ?
