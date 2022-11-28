#!/usr/bin/env sh

set -o errexit

# Always source the chillbox.config before the .env to prevent chillbox.config
# overwriting settings that are in the .env.
# shellcheck disable=SC1091
. /etc/chillbox/chillbox.config
# shellcheck disable=SC1091
. /home/dev/.env

mkdir -p /usr/local/src/
cd /usr/local/src/

/etc/chillbox/bin/site-init.sh

/etc/chillbox/bin/reload-templates.sh
nginx -t && rc-service nginx reload
