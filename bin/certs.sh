#!/usr/bin/env sh

set -o errexit

TECH_EMAIL="jake@weboftomorrow.com"
ACME_SH_VERSION="3.0.1"
#LETS_ENCRYPT_SERVER="letsencrypt"
LETS_ENCRYPT_SERVER="letsencrypt_test"

tmp_acme_tar=$(mktemp)
wget -O $tmp_acme_tar https://github.com/acmesh-official/acme.sh/archive/refs/tags/$ACME_SH_VERSION.tar.gz
tmp_md5sum=$(mktemp)
echo "21f4b4b88df5d7fb89bf15df9a8a8c94  -" > $tmp_md5sum
cat $tmp_acme_tar | md5sum --check $tmp_md5sum

tar -x --strip-components=1 -f $tmp_acme_tar acme.sh-$ACME_SH_VERSION/acme.sh

mkdir -p /etc/acmesh
mkdir -p /etc/acmesh/certs
./acme.sh --install \
  --email $TECH_EMAIL \
  --server $LETS_ENCRYPT_SERVER \
  --no-profile \
  --home /etc/acmesh \
  --accountconf /etc/acmesh/account.conf \
  --cert-home /etc/acmesh/certs \



./acme.sh --issue \
  --server $LETS_ENCRYPT_SERVER \
  --domain jengalaxyart.test \
  --webroot /srv/jengalaxyart/root/


./acme.sh --install-cert \
  --server $LETS_ENCRYPT_SERVER \
  --domain jengalaxyart.test \
  --cert-file /etc/nginx/some-path.cer \
  --key-file /etc/nginx/some-path.key \
  --reloadcmd 'nginx -t && nginx -s reload' \

# nginx conf
# ssl_certificate /etc/nginx/some-path.cer;
# ssl_certificate_key /etc/nginx/some-path.key;



