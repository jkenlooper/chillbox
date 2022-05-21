#!/usr/bin/env sh

set -o errexit

sleep 1

rm --verbose -f /var/lib/cloud/instance/user-data.txt
