#!/usr/bin/env sh

set -o errexit

working_dir=$(realpath $(dirname $0))

# Extract and set shell variables from JSON input
eval "$(jq -r '@sh "
  sites_artifact=\(.sites_artifact)
  "')"

tmp_dir=$(mktemp -d)
tar x -z -f dist/$sites_artifact -C "${tmp_dir}"

jq -s '[.[].domain_list] | flatten | {site_domains: .}' $(find "${tmp_dir}/sites" -type f -name '*.site.json') > site_domains.auto.tfvars.json
