#!/usr/bin/env sh

set -o errexit

tmp_output_file=$1

# Sanity check that these were set.
test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)

cd /usr/local/src/chillbox-terraform

terraform workspace select "$WORKSPACE" || \
  terraform workspace new "$WORKSPACE"

test "$WORKSPACE" = "$(terraform workspace show)" || (echo "Sanity check to make sure workspace selected matches environment has failed." && exit 1)

terraform state pull > "$tmp_output_file"
