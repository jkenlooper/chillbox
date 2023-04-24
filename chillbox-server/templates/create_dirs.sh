#!/usr/bin/env sh

set -o errexit


mkdir -p /etc/chillbox
chown {{ chillbox_user.name }}:{{ chillbox_user.name }} /etc/chillbox
chmod 0775 /etc/chillbox

mkdir -p /home/{{ chillbox_user.name }}/.aws
chown -R {{ chillbox_user.name }}:{{ chillbox_user.name }} /home/{{ chillbox_user.name }}/.aws
chmod 0700 /home/{{ chillbox_user.name }}/.aws
