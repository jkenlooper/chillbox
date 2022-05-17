#!/usr/bin/env sh

set -o errexit

working_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

# Need to use a log file for stdout since the stdout could be parsed as JSON by
# terraform external data source.
LOG_FILE="${working_dir}/${script_name}.log"
date > "$LOG_FILE"

showlog () {
  # Terraform external data will need to echo to stderr to show the message to
  # the user.
  >&2 echo "See log file: $LOG_FILE for further details."
}
trap showlog EXIT

# Extract and set shell variables from JSON input
sites_artifact_url=""
eval "$(jq -r '@sh "
  sites_artifact_url=\(.sites_artifact_url)
  "')"

{
  echo "set shell variables from JSON stdin"
  echo "  sites_artifact_url=$sites_artifact_url"
} >> "$LOG_FILE"

chillbox_artifact_version="$(cat VERSION)"
CHILLBOX_ARTIFACT="chillbox.$chillbox_artifact_version.tar.gz"
echo "CHILLBOX_ARTIFACT=$CHILLBOX_ARTIFACT" >> "$LOG_FILE"

sites_manifest_json="dist/sites.manifest.json"

SITES_ARTIFACT="$(basename "${sites_artifact_url}")"
echo "SITES_ARTIFACT=$SITES_ARTIFACT" >> "$LOG_FILE"

mkdir -p "$working_dir/dist"

# Create the chillbox artifact file
if [ ! -f "$working_dir/dist/$CHILLBOX_ARTIFACT" ]; then
  cd "$working_dir"
  tar -c -z -f "$working_dir/dist/$CHILLBOX_ARTIFACT" \
    terraform-020-chillbox/default.nginx.conf \
    terraform-020-chillbox/nginx.conf \
    terraform-020-chillbox/templates \
    bin \
    VERSION
else
  echo "No changes to existing chillbox artifact: $CHILLBOX_ARTIFACT" >> "$LOG_FILE"
fi

# Download or copy over the sites artifact file
if [ -f "$working_dir/dist/$SITES_ARTIFACT" ]; then
  echo "Sites artifact file already exists: dist/$SITES_ARTIFACT" >> "$LOG_FILE"

else

  first_char_of_sites_artifact_url="$(printf '%.1s' "$sites_artifact_url")"
  is_downloadable="$(printf '%.4s' "$sites_artifact_url")"
  if [ "$first_char_of_sites_artifact_url" = "/" ]; then
    cp -v "$sites_artifact_url" "$working_dir/dist/$SITES_ARTIFACT" >> "$LOG_FILE"
  elif [ "$is_downloadable" = "http" ]; then
    has_wget="$(command -v wget || echo "")"
    has_curl="$(command -v curl || echo "")"
    if [ -n "$has_wget" ]; then
      wget -a "$LOG_FILE" -O "$working_dir/dist/$SITES_ARTIFACT" "$sites_artifact_url"
    elif [ -n "$has_curl" ]; then
      curl --location --output "$working_dir/dist/$SITES_ARTIFACT" --silent --show-error "$sites_artifact_url" >> "$LOG_FILE"
    else
      echo "ERROR $0: No wget or curl commands found." >> "$LOG_FILE"
      exit 1
    fi

  else
    echo "ERROR $0: not supported sites artifact url: '$sites_artifact_url'" >> "$LOG_FILE"
    exit 1
  fi


  tmp_sites_dir="$(mktemp -d)"
  trap 'rm -r -i "$tmp_sites_dir"' EXIT
  cd "$tmp_sites_dir"
  tar x -f "$working_dir/dist/$SITES_ARTIFACT" sites

  sites="$(find sites -type f -name '*.site.json')"

  echo "$sites" >> "$LOG_FILE"

  for site_json in $sites; do
    cd "$tmp_sites_dir"
    slugname="${site_json%.site.json}"
    slugname="${slugname#sites/}"
    echo "$slugname" >> "$LOG_FILE"

    # TODO Validate the site_json file https://github.com/marksparkza/jschon

    version="$(jq -r '.version' "$site_json")"

    mkdir -p "${working_dir}/dist/${slugname}"
    dist_immutable_archive_file="$working_dir/dist/$slugname/$slugname-$version.immutable.tar.gz"
    dist_artifact_file="$working_dir/dist/$slugname/$slugname-$version.artifact.tar.gz"
    if [ -f "$dist_immutable_archive_file" ] && [ -f "$dist_artifact_file" ]; then
      echo "Skipping the 'make' command for $slugname" >> "$LOG_FILE"
      continue
    fi
    find "${working_dir}/dist/${slugname}" -type f \( -name "${slugname}-*.immutable.tar.gz" -o -name "${slugname}-*.artifact.tar.gz" \) -delete \
      || echo "No existing archive files to delete for ${slugname}" >> "$LOG_FILE"

    tmp_dir="$(mktemp -d)"
    git_repo="$(jq -r '.git_repo' "$site_json")"
    # TODO Change to be a zip of the source code files instead of depending on git.
    git clone --depth 1 --single-branch --branch "$version" --recurse-submodules "$git_repo" "$tmp_dir" >> "$LOG_FILE"
    cd "$tmp_dir"
    echo "Running the 'make' command for $slugname" >> "$LOG_FILE"
    make >> "$LOG_FILE"

    immutable_archive_file=$tmp_dir/$slugname-$version.immutable.tar.gz
    test -f "$immutable_archive_file" || (echo "No file at $immutable_archive_file" >> "$LOG_FILE" && exit 1)

    artifact_file="$tmp_dir/$slugname-$version.artifact.tar.gz"
    test -f "$artifact_file" || (echo "No file at $artifact_file" >> "$LOG_FILE" && exit 1)

    test ! -f "$dist_immutable_archive_file" || rm -f "$dist_immutable_archive_file"
    mkdir -p "$(dirname "$dist_immutable_archive_file")"
    mv "$immutable_archive_file" "$dist_immutable_archive_file"
    test ! -f "$dist_artifact_file" || rm -f "$dist_artifact_file"
    mkdir -p "$(dirname "$dist_artifact_file")"
    mv "$artifact_file" "$dist_artifact_file"

  done

  echo "SITES_ARTIFACT=$SITES_ARTIFACT" >> "$LOG_FILE"

  # Make a sites manifest json file
  cd "$tmp_sites_dir"
  tmp_file_list=$(mktemp)
  sites=$(find sites -type f -name '*.site.json')
  for site_json in $sites; do
    cd "$tmp_sites_dir"
    slugname=${site_json%.site.json}
    slugname=${slugname#sites/}
    version="$(jq -r '.version' "$site_json")"
    echo "$slugname/$slugname-$version.immutable.tar.gz" >> "$tmp_file_list"
    echo "$slugname/$slugname-$version.artifact.tar.gz" >> "$tmp_file_list"
  done
  # shellcheck disable=SC2016
  < "$tmp_file_list" xargs jq --null-input --args '$ARGS.positional' > "$working_dir/$sites_manifest_json"
  rm -f "$tmp_file_list"

fi

# Output the json
jq --null-input \
  --arg sites_artifact "$SITES_ARTIFACT" \
  --arg chillbox_artifact "$CHILLBOX_ARTIFACT" \
  --arg jq_sites_manifest "$sites_manifest_json" \
  --argjson sites_immutable_and_artifacts "$(jq -r -c '.' "$working_dir/$sites_manifest_json")" \
  '{
    sites_artifact:$sites_artifact,
    chillbox_artifact:$chillbox_artifact,
    sites_manifest:$jq_sites_manifest,
    sites:$sites_immutable_and_artifacts
  }'
