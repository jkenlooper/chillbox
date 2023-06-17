#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HERE

Build the sites artifact file and send to output directory. The SITES_ARTIFACT
env variable will be shown at the end which can be copied and set in the
chillbox.toml.

Usage:
  $script_name -h
  $script_name
  $script_name -s <url> -o <directory>

Options:
  -h                  Show this help message.

  -s <url>            Sites artifact URL. Can be an absolute path on the file
                      system or URL.

  -o <directory>      Output directory to store artifacts in.

Project directory: $project_dir

HERE
}

while getopts "hs:o:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) sites_artifact_url=$OPTARG ;;
    o) output_dir=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))


sites_artifact_url="${sites_artifact_url:-example}"
output_dir="${output_dir:-example}"
output_dir="$(realpath "$output_dir")"

chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox-server/$project_dir_hash"
mkdir -p "$output_dir"
mkdir -p "$chillbox_state_home"

export SITES_ARTIFACT_URL="$sites_artifact_url"

has_wget="$(command -v wget || echo "")"
has_curl="$(command -v curl || echo "")"

tmp_example_sites_dir="$(mktemp -d)"
tmp_sites_dir="$(mktemp -d)"
tmp_dir_for_site_domains_file=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_example_sites_dir"
  rm -rf "$tmp_sites_dir"
  rm -rf "$tmp_dir_for_site_domains_file"
}
trap cleanup EXIT

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

  if [ -z "$has_wget" ] && [ -z "$has_curl" ]; then
    echo "WARNING $script_name: Downloading site artifact files require 'wget' or 'curl' commands. Neither were found on this system."
  fi
}

download_file() {
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
  # UPKEEP due: "2023-10-09" label: "chillbox example site (site1)" interval: "+4 months"
  # https://github.com/jkenlooper/chillbox-example-site1/releases
  example_site_version="0.1.0-alpha.15"

  printf "\n\n%s\n" "INFO $script_name: Create example sites artifact to use."
  printf '%s\n' "Deploy using the example sites artifact? [y/n]"
  read -r confirm_using_example_sites_artifact
  if [ "${confirm_using_example_sites_artifact}" != "y" ]; then
    echo "Set the sites artifact URL to use via the '-s' option."
    echo "Exiting"
    exit 2
  fi
  echo "INFO $script_name: Continuing to use example sites artifact."
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
  # Download or copy over the sites artifact file
  if [ -f "$sites_artifact_file" ]; then
    echo "Sites artifact file already exists: $sites_artifact_file"

  else
    # Reset the verified sites marker file since the sites artifact file doesn't
    # exist.
    rm -f "$verified_sites_artifact_file"

    # Support using a local sites artifact if the first character is a '/';
    # otherwise it should be a downloadable URL.
    first_char_of_sites_artifact_url="$(printf '%.1s' "$SITES_ARTIFACT_URL")"
    is_downloadable="$(printf '%.4s' "$SITES_ARTIFACT_URL")"
    if [ "$first_char_of_sites_artifact_url" = "/" ]; then
      cp -v "$SITES_ARTIFACT_URL" "$sites_artifact_file"
    elif [ "$is_downloadable" = "http" ]; then
      if [ -n "$has_wget" ]; then
        wget -O "$sites_artifact_file" "$SITES_ARTIFACT_URL"
      elif [ -n "$has_curl" ]; then
        curl --location --output "$sites_artifact_file" --silent --show-error "$SITES_ARTIFACT_URL"
      else
        echo "ERROR $script_name: No wget or curl commands found."
        exit 1
      fi
    else
      echo "ERROR $script_name: not supported sites artifact url: '$SITES_ARTIFACT_URL'"
      exit 1
    fi

    tar x -f "$sites_artifact_file" -C "$tmp_sites_dir" sites
    chmod --recursive u+rw "$tmp_sites_dir"

    sites="$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')"

    echo "$sites"

    for site_json in $sites; do
      slugname="$(basename "$site_json" .site.json)"
      echo "$slugname"

      release="$(jq -r --exit-status '.release' "$site_json")"

      first_char_of_release_url="$(printf '%.1s' "$release")"
      is_downloadable="$(printf '%.4s' "$release")"
      release_filename="$(basename "$release")"
      if [ "$first_char_of_release_url" = "/" ]; then
        cp -v "$release" "$tmp_sites_dir/"
      elif [ "$is_downloadable" = "http" ]; then
        if [ -n "$has_wget" ]; then
          wget -O "$tmp_sites_dir/$release_filename" "$release"
        elif [ -n "$has_curl" ]; then
          curl --location --output "$tmp_sites_dir/$release_filename" --silent --show-error "$release"
        else
          echo "ERROR $script_name: No wget or curl commands found."
          exit 1
        fi
      else
        echo "ERROR $script_name: not supported release url: '$release'"
        exit 1
      fi

      # Add the version field to the site json to make it easier for scripts to
      # use that value.
      # Fallback on version already set if error from 'make inspect.VERSION' command.
      tmp_dir_for_version="$(mktemp -d)"
      mkdir -p "$tmp_dir_for_version/$slugname"
      tar x -f "$tmp_sites_dir/$release_filename" -C "$tmp_dir_for_version/$slugname" --strip-components=1
      chmod --recursive u+rw "$tmp_dir_for_version"
      echo "Running the 'make inspect.VERSION' command for $slugname and falling back on version set in site json file."
      # Fails if no version can be determined for the site.
      version="$(make --silent -C "$tmp_dir_for_version/$slugname" inspect.VERSION || jq -r --exit-status '.version' "$site_json")"
      echo "$slugname version: $version"
      rm -rf "$tmp_dir_for_version"
      cp "$site_json" "$site_json.original"
      jq --arg jq_version "$version" '.version |= $jq_version' < "$site_json.original" > "$site_json"
      rm "$site_json.original"

      (
        # Sub shell for handling of the 'cd' to the slugname directory. This
        # allows custom 'cmd's in the site.json work relatively to the project
        # root directory.
        tmp_dir_for_env_cmd="$(mktemp -d)"
        mkdir -p "$tmp_dir_for_env_cmd/$slugname"
        tar x -f "$tmp_sites_dir/$release_filename" -C "$tmp_dir_for_env_cmd/$slugname" --strip-components=1
        chmod --recursive u+rw "$tmp_dir_for_env_cmd"
        cd "$tmp_dir_for_env_cmd/$slugname"
        tmp_eval="$(mktemp)"
        # Warning! The '.cmd' value is executed on the host here. The content in
        # the site.json should be trusted, but it is a little safer to confirm
        # with the user first.
        jq -r \
          '.env[] | select(.cmd != null) | .name + "=\"$(" + .cmd + ")\"; export " + .name' \
          "$site_json" > "$tmp_eval"
        # Only need to prompt the user if a cmd was set.
        if [ -n "$(sed 's/\s//g; /^$/d' "$tmp_eval")" ]; then
          printf "\n\n--- ###\n\n"
          cat "$tmp_eval"
          printf "\n\n--- ###\n\n"
          printf "%s\n" "Execute the above commands so the matching env fields from $site_json can be updated? [y/n]"
          read -r eval_cmd_confirm
          if [ "$eval_cmd_confirm" = "y" ]; then
            eval "$(cat "$tmp_eval")"
            cp "$site_json" "$site_json.original"
            jq \
              '(.env[] | select(.cmd != null)) |= . + {name: .name, value: $ENV[.name]}' < "$site_json.original" > "$site_json"
            rm "$site_json.original"
            jq '.env' "$site_json"
            printf "%s\n" "The env from the $site_json has been updated and is shown above. Continue with build? [y/n]"
            read -r continue_build_confirm
            if [ "$continue_build_confirm" != "y" ]; then
              echo "Exiting build since the updated env in $site_json did not pass review."
              exit 1
            fi
          fi
          rm -f "$tmp_eval"
        fi
        rm -rf "$tmp_dir_for_env_cmd"
      )

      mkdir -p "$chillbox_state_home/sites/$slugname"
      dist_immutable_archive_file="$chillbox_state_home/sites/$slugname/$slugname-$version.immutable.tar.gz"
      dist_artifact_file="$chillbox_state_home/sites/$slugname/$slugname-$version.artifact.tar.gz"
      if [ -f "$dist_immutable_archive_file" ] && [ -f "$dist_artifact_file" ]; then
        echo "The immutable archive file and site artifact file already exist:"
        echo "  $dist_immutable_archive_file"
        echo "  $dist_artifact_file"
        echo "Skipping the 'make' command for $slugname"
        continue
      fi
      find "$chillbox_state_home/sites/$slugname" -type f \( -name "${slugname}-*.immutable.tar.gz" -o -name "${slugname}-*.artifact.tar.gz" \) -delete \
        || echo "No existing archive files to delete for $slugname"

      tmp_dir="$(mktemp -d)"
      mkdir -p "$tmp_dir/$slugname"
      tar x -f "$tmp_sites_dir/$release_filename" -C "$tmp_dir/$slugname" --strip-components=1
      chmod --recursive u+rw "$tmp_dir"

      echo "Running the 'make' command for $slugname which should make dist/immutable.tar.gz and dist/artifact.tar.gz"
      make --silent -C "$tmp_dir/$slugname"
      chmod --recursive u+rw "$tmp_dir"

      immutable_archive_file="$tmp_dir/$slugname/dist/immutable.tar.gz"
      test -f "$immutable_archive_file" || (echo "ERROR $script_name: No file at $immutable_archive_file" && exit 1)

      artifact_file="$tmp_dir/$slugname/dist/artifact.tar.gz"
      test -f "$artifact_file" || (echo "ERROR $script_name: No file at $artifact_file" && exit 1)

      echo "Saving the built files in the chillbox state directory for the $slugname site to avoid rebuilding the same version next time."
      test ! -f "$dist_immutable_archive_file" || rm -f "$dist_immutable_archive_file"
      mkdir -p "$(dirname "$dist_immutable_archive_file")"
      mv "$immutable_archive_file" "$dist_immutable_archive_file"
      test ! -f "$dist_artifact_file" || rm -f "$dist_artifact_file"
      mkdir -p "$(dirname "$dist_artifact_file")"
      mv "$artifact_file" "$dist_artifact_file"

      # Clean up
      rm -rf "$tmp_dir"

    done

    echo "Making a sites manifest json file at $sites_manifest_json_file"
    tmp_file_list=$(mktemp)
    sites=$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')
    for site_json in $sites; do
      slugname="$(basename "$site_json" .site.json)"
      version="$(jq -r '.version' "$site_json")"
      echo "$slugname/$slugname-$version.immutable.tar.gz" >> "$tmp_file_list"
      echo "$slugname/$slugname-$version.artifact.tar.gz" >> "$tmp_file_list"
    done
    # shellcheck disable=SC2016
    < "$tmp_file_list" xargs jq --null-input --args '$ARGS.positional' > "$sites_manifest_json_file"
    rm -f "$tmp_file_list"

    # Need to repackage the sites artifact since the version fields have been
    # updated.
    rm -f "$sites_artifact_file"
    tar c -z -f "$sites_artifact_file" -C "$tmp_sites_dir" sites

  fi
}

verify_built_artifacts() {
  # TODO Implement more simply instead of the old_sh way of running a python
  # script inside a docker container.
  printf "\n\n%s\n" "INFO $script_name: Verify that the artifacts that were built have met the service contracts before continuing."

  if [ -e "$verified_sites_artifact_file" ]; then
    echo "INFO $script_name: Site artifact $SITES_ARTIFACT has already been verified; skipping."
  else
    echo "TODO Verify site.json for each site against a site.schema.json file."
    touch "$verified_sites_artifact_file"
  fi
}

generate_site_domains_file() {
  site_domains_file="$chillbox_state_home/site_domains.auto.tfvars.json"
  tar x -z -f "$chillbox_state_home/$SITES_ARTIFACT" -C "${tmp_dir_for_site_domains_file}"
  find "${tmp_dir_for_site_domains_file}/sites" -type f -name '*.site.json' -exec \
    jq -s '[.[].domain_list] | flatten | {site_domains: .}' {} + > "$site_domains_file"
}

output_artifacts() {
  # Output site artifact file
  mkdir -p "$output_dir/_sites"
  if [ ! -e "$output_dir/_sites/$SITES_ARTIFACT" ]; then
    cp "$chillbox_state_home/$SITES_ARTIFACT" \
      "$output_dir/_sites/$SITES_ARTIFACT"
  else
    echo "INFO $script_name: No changes to existing site artifact: $SITES_ARTIFACT"
  fi

  # Output artifacts for each site
  jq -r '.[]' "$sites_manifest_json_file" \
    | while read -r artifact_file; do
      test -n "${artifact_file}" || continue
      slugname="$(dirname "$artifact_file")"
      artifact="$(basename "$artifact_file")"
      mkdir -p "$output_dir/$slugname/artifacts"

      if [ ! -e "$output_dir/$slugname/artifacts/$artifact" ]; then
        echo "INFO $script_name: Uploading artifact: $artifact_file"
        cp "$chillbox_state_home/sites/$artifact_file" \
          "$output_dir/$slugname/artifacts/$artifact"
      else
        echo "INFO $script_name: No changes to existing artifact: $artifact_file"
      fi
    done
}


check_for_required_commands

if [ "${SITES_ARTIFACT_URL}" = "example" ]; then
  printf "\n\n%s\n" "WARNING $script_name: Using the example sites artifact. Use the option '-s' to set a specific site artifact URL to use."
  create_example_site_tar_gz
fi

test -n "${SITES_ARTIFACT_URL}" || (echo "ERROR $script_name: SITES_ARTIFACT_URL variable is empty" && exit 1)
if [ "$(basename "$SITES_ARTIFACT_URL" ".tar.gz")" = "$(basename "$SITES_ARTIFACT_URL")" ]; then
  echo "ERROR $script_name: The SITES_ARTIFACT_URL must end with a '.tar.gz' extension."
  exit 1
fi

SITES_ARTIFACT="$(basename "${SITES_ARTIFACT_URL}")"
export SITES_ARTIFACT
sites_artifact_file="$chillbox_state_home/$SITES_ARTIFACT"
sites_manifest_json="sites.manifest.json"
sites_manifest_json_file="$chillbox_state_home/$sites_manifest_json"

verified_sites_artifact_file="$chillbox_state_home/verified_sites_artifact/$SITES_ARTIFACT"
mkdir -p "$(dirname "$verified_sites_artifact_file")"

build_artifacts
verify_built_artifacts
generate_site_domains_file
output_artifacts

# Output the SITES_ARTIFACT so the chillbox.toml env var can be set to it.
# ARTIFACT_BUCKET_NAME/_sites/SITES_ARTIFACT is the location it will be in the
# s3 bucket.
echo "SITES_ARTIFACT = \"$SITES_ARTIFACT\""
