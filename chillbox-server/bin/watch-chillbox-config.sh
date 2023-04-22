#!/usr/bin/env sh

set -o errexit

echo "Starting watch process on /etc/chillbox/chillbox.config file."

printf '/etc/chillbox/chillbox.config' | entr -n -p -r /etc/chillbox/bin/update.sh
