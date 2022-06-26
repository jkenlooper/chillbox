#!/usr/bin/env sh

set -o errexit

test -n "$WORKSPACE" || (echo "ERROR $0: WORKSPACE variable is empty" && exit 1)
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $0: CHILLBOX_INSTANCE variable is empty" && exit 1)

# Extract and set shell variables from JSON input
sites_artifact=""
site_domains_file=""
eval "$(jq -r '@sh "
  sites_artifact=\(.sites_artifact)
  site_domains_file=\(.site_domains_file)
  "')"

chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

tar x -z -f "$chillbox_state_home/$sites_artifact" -C "${tmp_dir}"

find "${tmp_dir}/sites" -type f -name '*.site.json' -exec \
  jq -s '[.[].domain_list] | flatten | {site_domains: .}' {} + > "$site_domains_file"
