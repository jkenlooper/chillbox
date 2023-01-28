#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

echo "INFO $script_name: Running init nginx"


mkdir -p /srv/chillbox/
chown -R nginx /srv/chillbox/
mkdir -p /var/cache/nginx/
chown -R nginx /var/cache/nginx
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/chillbox/
chown -R nginx /var/log/nginx/chillbox/
mkdir -p /etc/nginx/conf.d/
find /etc/nginx/conf.d/ -name '*.conf' -not -name 'default.conf' -delete
chown -R nginx /etc/nginx/conf.d/

chown -R nginx /etc/nginx/conf.d/
