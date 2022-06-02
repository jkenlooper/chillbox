#!/usr/bin/env sh

set -o errexit

tfstate_file=$1

test -n "$tfstate_file" || (echo "ERROR $0: first arg is empty." && exit 1)
test -e "$tfstate_file" || (echo "ERROR $0: file doesn't exist: $tfstate_file" && exit 1)
test -s "$tfstate_file" || (echo "ERROR $0: file is empty: $tfstate_file" && exit 1)

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

cd /usr/local/src/chillbox-terraform

terraform workspace select "$WORKSPACE" || \
  terraform workspace new "$WORKSPACE"

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "ERROR $0: Sanity check to make sure workspace selected matches environment has failed." && exit 1)

terraform state push "$tfstate_file"
