#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$0")")"

# Extract and set shell variables from JSON input
sites_artifact=""
eval "$(jq -r '@sh "
  sites_artifact=\(.sites_artifact)
  "')"

tmp_dir=$(mktemp -d)
tar x -z -f "$working_dir/dist/$sites_artifact" -C "${tmp_dir}"

find "${tmp_dir}/sites" -type f -name '*.site.json' -exec \
  jq -s '[.[].domain_list] | flatten | {site_domains: .}' {} + > "$working_dir/site_domains.auto.tfvars.json"
