#!/usr/bin/env sh

set -o errexit


mkdir -p /etc/chillbox
chown {{ chillbox_user.name }}:{{ chillbox_user.name }} /etc/chillbox
chmod 0775 /etc/chillbox

mkdir -p /home/{{ chillbox_user.name }}/.aws
chown -R {{ chillbox_user.name }}:{{ chillbox_user.name }} /home/{{ chillbox_user.name }}/.aws
chmod 0700 /home/{{ chillbox_user.name }}/.aws

# Create these dirs to support running certbot as user.
mkdir -p /etc/letsencrypt/accounts
chown -R {{ chillbox_user.name }}:{{ chillbox_user.name }} /etc/letsencrypt
mkdir -p /var/log/letsencrypt
chown -R {{ chillbox_user.name }}:{{ chillbox_user.name }} /var/log/letsencrypt
mkdir -p /var/lib/letsencrypt
chown -R {{ chillbox_user.name }}:{{ chillbox_user.name }} /var/lib/letsencrypt
mkdir -p /srv/chillbox/.well-known/acme-challenge
chown -R {{ chillbox_user.name }}:{{ chillbox_user.name }} /srv/chillbox/.well-known/acme-challenge
chmod -R ug+w /srv/chillbox/.well-known/acme-challenge

# Support setting env variables for all users.
touch /etc/profile.d/chillbox-env.sh
chown {{ chillbox_user.name }}:{{ chillbox_user.name }} /etc/profile.d/chillbox-env.sh
