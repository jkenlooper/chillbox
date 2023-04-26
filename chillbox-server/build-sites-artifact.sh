#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HERE

Build the sites artifact file.

Usage:
  $script_name -h
  $script_name [<options>]

Options:
  -h                  Show this help message.

  -s <url>            Sites artifact URL. Can be an absolute path on the file
                      system or URL.

HERE
}

while getopts "hw:i:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    w) sites_artifact_url=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

project_dir_hash="$(echo "$project_dir" | md5sum | cut -f1 -d' ')"
chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox-server/$project_dir_hash"

export SITES_ARTIFACT_URL="$sites_artifact_url"

check_for_required_commands() {
  for required_command in \
    realpath \
    docker \
    jq \
    make \
    md5sum \
    tar \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." && exit 1)
  done

  has_wget="$(command -v wget || echo "")"
  has_curl="$(command -v curl || echo "")"
  if [ -z "$has_wget" ] && [ -z "$has_curl" ]; then
    echo "WARNING $script_name: Downloading site artifact files require 'wget' or 'curl' commands. Neither were found on this system."
  fi
}

download_file() {
  has_wget="$(command -v wget || echo "")"
  has_curl="$(command -v curl || echo "")"
  remote_file_url="$1"
  output_file="$2"
  test -n "$remote_file_url" || (echo "ERROR $script_name: no remote file URL arg (first arg)" && exit 1)
  test -n "$output_file" || (echo "ERROR $script_name: no output file arg (second arg)" && exit 1)
  test ! -e "$output_file" || (echo "ERROR $script_name: output file already exists: $output_file" && exit 1)
  output_file_dir="$(dirname "$output_file")"
  mkdir -p "$output_file_dir"
  if [ -n "$has_wget" ]; then
    wget -q -O "$output_file" "$remote_file_url" \
      || (rm -f "$output_file" && echo "ERROR $script_name: Failed to download from URL $remote_file_url" && exit 1)
  elif [ -n "$has_curl" ]; then
    curl --location --output "$output_file" --silent --show-error --fail "$remote_file_url" \
      || (rm -f "$output_file" && echo "ERROR $script_name: Failed to download from URL $remote_file_url" && exit 1)
  else
    echo "ERROR $script_name: No wget or curl commands found."
    exit 1
  fi
}

create_example_site_tar_gz() {
  # UPKEEP due: "2023-05-09" label: "chillbox example site (site1)" interval: "+4 months"
  # https://github.com/jkenlooper/chillbox-example-site1/releases
  example_site_version="0.1.0-alpha.13"

  printf "\n\n%s\n" "INFO $script_name: Create example sites artifact to use."
  printf '%s\n' "Deploy using the example sites artifact? [y/n]"
  read -r confirm_using_example_sites_artifact
  if [ "${confirm_using_example_sites_artifact}" != "y" ]; then
    echo "Update the SITES_ARTIFACT_URL variable to not be set to 'example'."
    echo "Exiting"
    exit 2
  fi
  echo "INFO $script_name: Continuing to use example sites artifact."
  tmp_example_sites_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_example_sites_dir"' EXIT
  example_sites_version="$(make --silent --directory="$project_dir" --no-print-directory inspect.VERSION)"
  echo "example_sites_version ($example_sites_version)"
  export SITES_ARTIFACT_URL="$tmp_example_sites_dir/chillbox-example-sites-$example_sites_version.tar.gz"
  # Copy and modify the site json release field for this example site so it can
  # be a file path instead of the https://example.test/ URL.
  cp -R "$project_dir/example/sites" "$tmp_example_sites_dir/"
  if [ ! -e "$chillbox_state_home/site1-$example_site_version.tar.gz" ]; then
    echo "INFO $script_name: No local cached copy of example site1. Downloading new one from https://github.com/jkenlooper/chillbox-example-site1/releases"
    download_file \
      "https://github.com/jkenlooper/chillbox-example-site1/releases/download/$example_site_version/site1.tar.gz" \
      "$chillbox_state_home/site1-$example_site_version.tar.gz"
  fi
  echo "INFO $script_name: Updating example site1.site.json to use $chillbox_state_home/site1-$example_site_version.tar.gz"
  jq \
    --arg jq_release_file_path "$chillbox_state_home/site1-$example_site_version.tar.gz" \
    '.release |= $jq_release_file_path' \
    < "$project_dir/example/sites/site1.site.json" \
    > "$tmp_example_sites_dir/sites/site1.site.json"
  tar c -z -f "$SITES_ARTIFACT_URL" -C "$tmp_example_sites_dir" sites
}

build_artifacts() {
  # TODO combine and move from old_sh/chillbox.sh, old_sh/src/local/build-artifacts.sh
}

verify_built_artifacts() {
  # TODO move from old_sh/chillbox.sh
}

generate_site_domains_file() {
  # TODO move from old_sh/chillbox.sh
}

upload_artifacts() {
  # TODO move from chillbox-server/terraform/020-chillbox/upload-artifacts.sh
}


check_for_required_commands

if [ "${SITES_ARTIFACT_URL}" = "example" ]; then
  printf "\n\n%s\n" "WARNING $script_name: Using the example sites artifact."
  create_example_site_tar_gz
fi

test -n "${SITES_ARTIFACT_URL}" || (echo "ERROR $script_name: SITES_ARTIFACT_URL variable is empty" && exit 1)
if [ "$(basename "$SITES_ARTIFACT_URL" ".tar.gz")" = "$(basename "$SITES_ARTIFACT_URL")" ]; then
  echo "ERROR $script_name: The SITES_ARTIFACT_URL must end with a '.tar.gz' extension."
  exit 1
fi

# TODO build_artifacts
# TODO verify_built_artifacts
# TODO generate_site_domains_file
# TODO upload_artifacts

# TODO Output the SITES_ARTIFACT so the chillbox.toml env var can be set to it.
# ARTIFACT_BUCKET_NAME/_sites/SITES_ARTIFACT is the location it will be in the
# s3 bucket.
