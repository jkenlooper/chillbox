#!/usr/bin/env sh

set -o errexit

# shellcheck disable=SC1091
. /home/dev/.env

mkdir -p /usr/local/src/
cd /usr/local/src/

/etc/chillbox/bin/site-init.sh

/etc/chillbox/bin/reload-templates.sh
nginx -t && nginx -s reload
