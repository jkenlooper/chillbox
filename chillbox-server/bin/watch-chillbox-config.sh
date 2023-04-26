#!/usr/bin/env sh

set -o errexit

echo "Starting watch process on /etc/profile.d/chillbox-config.sh file."

printf '/etc/profile.d/chillbox-config.sh' | entr -n -p -r /etc/chillbox/bin/update.sh
