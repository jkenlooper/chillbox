#!/usr/bin/env sh

set -o errexit


for d in \
  /etc/chillbox \
  /etc/chillbox/nginx/templates \
  /etc/chillbox/bin \
  /var/lib/chillbox/python \
  /etc/nginx/conf.d \
  ; do
  mkdir -p "$d"
  chown {{ chillbox_user.name }}:{{ chillbox_user.name }} "$d"
  chmod 0755 "$d"
done

# Support chillbox scripts that will execute with root privileges, but need to
# drop to the owner of the server when executing other commands.
mkdir -p /var/lib/chillbox
printf "%s" '{{ chillbox_user.name }}' > /var/lib/chillbox/owner
chmod 0444 /var/lib/chillbox/owner

{% include 'chillbox:create_dirs-PATH_SENSITIVE.jinja' %}

{% include 'chillbox:create_dirs-PATH_SECRETS.jinja' %}

mkdir -p /etc/nginx
touch /etc/nginx/nginx.conf
chown {{ chillbox_user.name }}:{{ chillbox_user.name }} /etc/nginx/nginx.conf
chmod 0644 /etc/nginx/nginx.conf

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
chmod 0755 /etc/profile.d/chillbox-env.sh
touch /etc/profile.d/chillbox-config.sh
chown {{ chillbox_user.name }}:{{ chillbox_user.name }} /etc/profile.d/chillbox-config.sh
chmod 0755 /etc/profile.d/chillbox-config.sh
