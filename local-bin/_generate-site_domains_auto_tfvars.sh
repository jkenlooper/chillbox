#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$(dirname "$0")")")"

# Extract and set shell variables from JSON input
sites_artifact=""
site_domains_file=""
eval "$(jq -r '@sh "
  sites_artifact=\(.sites_artifact)
  site_domains_file=\(.site_domains_file)
  "')"

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

tar x -z -f "$working_dir/dist/$sites_artifact" -C "${tmp_dir}"

find "${tmp_dir}/sites" -type f -name '*.site.json' -exec \
  jq -s '[.[].domain_list] | flatten | {site_domains: .}' {} + > "$site_domains_file"
