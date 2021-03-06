#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$0")")"
script_name="$(basename "$0")"

# Need to use a log file for stdout since the stdout is parsed as JSON.
LOG_FILE="${working_dir}/${script_name}.log"
date > "$LOG_FILE"

# Extract and set shell variables from JSON input
sites_artifact=""
artifact_module_tf_file=""
eval "$(jq -r '@sh "
  sites_artifact=\(.sites_artifact)
  artifact_module_tf_file=\(.artifact_module_tf_file)
  "')"

tmp_dir="$(mktemp -d)"
tar x -f "dist/$sites_artifact" -C "${tmp_dir}"
find "$tmp_dir/sites" -type f -name '*.site.json' | \
  while read -r site_json; do
    echo "$site_json" >> "$LOG_FILE"
    jq '.' "$site_json" >> "$LOG_FILE"
    slugname="$(basename "$site_json" .site.json)"
    version="$(jq -r '.version' "$site_json")"
    if [ -z "$(jq -r -c '.terraform // [] | .[] // {} | .module // ""' "${site_json}")" ]; then
      # No terraform module defined; skip.
      continue
    fi
    mkdir -p artifact-modules
    jq -c '.terraform[]' "${site_json}" | \
      while read -r terraform_json; do

        module=$(echo "${terraform_json}" | jq -r '.module')
        terraform_variables=$(echo "${terraform_json}" | jq -r '.variables // [] | .[] | "\(.name) = \"\(.value)\""')
        tar x -z -f "dist/${slugname}/${slugname}-${version}.artifact.tar.gz" -C artifact-modules/ "${slugname}/${module}"
        cat <<HERE >> "$working_dir/$artifact_module_tf_file"
module "${slugname}-${module}" {
  source = "./artifact-modules/${slugname}/${module}"
  ${terraform_variables}
}
HERE
      done

  done
