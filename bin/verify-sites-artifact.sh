#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

SITES_ARTIFACT="${SITES_ARTIFACT:-}"
sites_artifact_file="/var/lib/verify-sites/dist/$SITES_ARTIFACT"
test -n "${SITES_ARTIFACT}" || (echo "ERROR $script_name: The SITES_ARTIFACT variable is empty." && exit 1)
test -e "${sites_artifact_file}" || (echo "ERROR $script_name: No sites artifact file found at '$sites_artifact_file'." && exit 1)

SITES_MANIFEST="${SITES_MANIFEST:-}"
sites_manifest_file="/var/lib/verify-sites/dist/$SITES_MANIFEST"
test -n "${SITES_MANIFEST}" || (echo "ERROR $script_name: The SITES_MANIFEST variable is empty." && exit 1)
test -e "${sites_manifest_file}" || (echo "ERROR $script_name: No sites manifest file found at '$sites_manifest_file'." && exit 1)


# TODO Extract and run checks needed to verify that all sites meet requirements.

tmp_sites_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_sites_dir"
}
trap cleanup EXIT


tar x -f "$sites_artifact_file" -C "$tmp_sites_dir" sites
chmod --recursive u+rw "$tmp_sites_dir"

sites="$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')"

for site_json in $sites; do
  # TODO Validate the site_json file https://github.com/marksparkza/jschon
  # run the python script and pass it the schema file

  echo "TODO check $site_json"
  # TODO Extract each file listed in the sites manifest and verify
done
