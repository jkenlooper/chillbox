#!/usr/bin/env sh

set -o errexit

# shellcheck disable=SC1091
. /home/dev/.env

## WORKDIR /usr/local/src/
mkdir -p /usr/local/src/
cd /usr/local/src/

## RUN SITE_INIT

/etc/chillbox/bin/site-init.sh

# TODO RUN NGINX_CONF ?
/etc/chillbox/bin/reload-templates.sh
nginx -t
# TODO reload nginx service?
rc-service nginx reload
