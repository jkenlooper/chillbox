#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

tfstate_file=$1

test -n "$tfstate_file" || (echo "ERROR $script_name: first arg is empty." && exit 1)
test -e "$tfstate_file" || (echo "ERROR $script_name: file doesn't exist: $tfstate_file" && exit 1)
test -s "$tfstate_file" || (echo "ERROR $script_name: file is empty: $tfstate_file" && exit 1)

cd /usr/local/src/chillbox-terraform

terraform state push "$tfstate_file"
