#!/usr/bin/env sh

set -o errexit

tfstate_file=$1

test -n "$tfstate_file" || (echo "ERROR $0: first arg is empty." && exit 1)
test -e "$tfstate_file" || (echo "ERROR $0: file doesn't exist: $tfstate_file" && exit 1)
test -s "$tfstate_file" || (echo "ERROR $0: file is empty: $tfstate_file" && exit 1)

cd /usr/local/src/chillbox-terraform

terraform state push "$tfstate_file"
