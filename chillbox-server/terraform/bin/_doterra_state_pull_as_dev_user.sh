#!/usr/bin/env sh

set -o errexit

tmp_output_file=$1

cd /usr/local/src/chillbox-terraform

terraform state pull > "$tmp_output_file"
