#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
script_name="$(basename "$0")"

usage() {
  cat <<HERE

Build artifacts by processing the provided sites artifact file.

Usage:
  $script_name -h
  $script_name -s <sites-artifact> -o <output-file>

Options:
  -h                  Show this help message.

  -s <sites-artifact> An absolute path or URL to a sites artifact file.

  -o <output-file>    The output file will have environment variables that should be evaluated.

HERE
}

sites_artifact_url=""
output_file=""
while getopts "hs:o:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) sites_artifact_url=$OPTARG ;;
    o) output_file=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

test -n "$sites_artifact_url" || (echo "ERROR $script_name: No sites-artifact set" >&2 && usage && exit 1)
test -n "$output_file" || (echo "ERROR $script_name: No output-file set" >&2 && usage && exit 1)
test -f "$output_file" || (echo "ERROR $script_name: The output-file ($output_file) is not a file" >&2 && usage && exit 1)

# Need to use a log file for stdout since the stdout could be parsed as JSON by
# terraform external data source.
test -n "$CHILLBOX_INSTANCE" || (echo "ERROR $script_name: CHILLBOX_INSTANCE variable is empty" && exit 1)
test -n "$WORKSPACE" || (echo "ERROR $script_name: WORKSPACE variable is empty" && exit 1)
chillbox_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$CHILLBOX_INSTANCE/$WORKSPACE"

build_artifacts_logs_dir="${chillbox_state_home}/build_artifacts_logs"
mkdir -p "$build_artifacts_logs_dir"
log_timestamp="$(date -I)"
log_file="${build_artifacts_logs_dir}/${log_timestamp}.log"
printf "\n\n\n%s\n" "### START ###" >> "$log_file"
date >> "$log_file"

showlog () {
  # Terraform external data will need to echo to stderr to show the message to
  # the user.
  >&2 echo "INFO $script_name: Updated log file $log_file"
}
trap showlog EXIT

has_wget="$(command -v wget || echo "")"
has_curl="$(command -v curl || echo "")"

echo "Sites artifact is at $sites_artifact_url" >> "$log_file"

chillbox_artifact_version="$(make --silent --directory="$project_dir" inspect.VERSION)"
chillbox_artifact="chillbox.$chillbox_artifact_version.tar.gz"
echo "chillbox_artifact: $chillbox_artifact" >> "$log_file"

chillbox_dist_file="${XDG_STATE_HOME:-"$HOME/.local/state"}/chillbox/$chillbox_artifact"

sites_manifest_json="sites.manifest.json"
sites_manifest_json_file="$chillbox_state_home/$sites_manifest_json"

sites_artifact="$(basename "${sites_artifact_url}")"
echo "sites_artifact=$sites_artifact" >> "$log_file"

sites_artifact_file="$chillbox_state_home/$sites_artifact"
mkdir -p "$chillbox_state_home"

"$project_dir/src/local/redis/update-redis-conf-patch.sh"
cp "$project_dir/src/local/redis/chillbox.redis.conf" "$project_dir/src/chillbox/redis/redis.conf"

# Create the chillbox artifact file
if [ ! -f "$chillbox_dist_file" ]; then
  tar c -z -f "$chillbox_dist_file" \
    -C "$project_dir/src/chillbox" \
    nginx/default.nginx.conf \
    nginx/nginx.conf \
    nginx/chillbox.ssl_cert.include \
    nginx/templates \
    bin \
    dep \
    keys \
    redis \
    VERSION
else
  echo "No changes to existing chillbox artifact: $chillbox_artifact" >> "$log_file"
fi

# Download or copy over the sites artifact file
if [ -f "$sites_artifact_file" ]; then
  echo "Sites artifact file already exists: $sites_artifact_file" >> "$log_file"

else
  # Reset the verified sites marker file since the sites artifact file doesn't
  # exist.
  rm -f "$chillbox_state_home/verified_sites_artifact/$sites_artifact"

  # Support using a local sites artifact if the first character is a '/';
  # otherwise it should be a downloadable URL.
  first_char_of_sites_artifact_url="$(printf '%.1s' "$sites_artifact_url")"
  is_downloadable="$(printf '%.4s' "$sites_artifact_url")"
  if [ "$first_char_of_sites_artifact_url" = "/" ]; then
    cp -v "$sites_artifact_url" "$sites_artifact_file" >> "$log_file"
  elif [ "$is_downloadable" = "http" ]; then
    if [ -n "$has_wget" ]; then
      wget -a "$log_file" -O "$sites_artifact_file" "$sites_artifact_url"
    elif [ -n "$has_curl" ]; then
      curl --location --output "$sites_artifact_file" --silent --show-error "$sites_artifact_url" >> "$log_file"
    else
      echo "ERROR $script_name: No wget or curl commands found." >> "$log_file"
      exit 1
    fi
  else
    echo "ERROR $script_name: not supported sites artifact url: '$sites_artifact_url'" >> "$log_file"
    exit 1
  fi

  tmp_sites_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_sites_dir"' EXIT
  tar x -f "$sites_artifact_file" -C "$tmp_sites_dir" sites
  chmod --recursive u+rw "$tmp_sites_dir"

  sites="$(find "$tmp_sites_dir/sites" -type f -name '*.site.json')"

  echo "$sites" >> "$log_file"

  for site_json in $sites; do
    slugname="$(basename "$site_json" .site.json)"
    echo "$slugname" >> "$log_file"

    release="$(jq -r --exit-status '.release' "$site_json")"

    first_char_of_release_url="$(printf '%.1s' "$release")"
    is_downloadable="$(printf '%.4s' "$release")"
    release_filename="$(basename "$release")"
    if [ "$first_char_of_release_url" = "/" ]; then
      cp -v "$release" "$tmp_sites_dir/" >> "$log_file"
    elif [ "$is_downloadable" = "http" ]; then
      if [ -n "$has_wget" ]; then
        wget -a "$log_file" -O "$tmp_sites_dir/$release_filename" "$release"
      elif [ -n "$has_curl" ]; then
        curl --location --output "$tmp_sites_dir/$release_filename" --silent --show-error "$release" >> "$log_file"
      else
        echo "ERROR $script_name: No wget or curl commands found." >> "$log_file"
        exit 1
      fi
    else
      echo "ERROR $script_name: not supported release url: '$release'" >> "$log_file"
      exit 1
    fi

    # Add the version field to the site json to make it easier for scripts to
    # use that value.
    # Fallback on version already set if error from 'make inspect.VERSION' command.
    tmp_dir_for_version="$(mktemp -d)"
    mkdir -p "$tmp_dir_for_version/$slugname"
    tar x -f "$tmp_sites_dir/$release_filename" -C "$tmp_dir_for_version/$slugname" --strip-components=1
    chmod --recursive u+rw "$tmp_dir_for_version"
    echo "Running the 'make inspect.VERSION' command for $slugname and falling back on version set in site json file." >> "$log_file"
    # Fails if no version can be determined for the site.
    version="$(make --silent -C "$tmp_dir_for_version/$slugname" inspect.VERSION || jq -r --exit-status '.version' "$site_json")"
    echo "$slugname version: $version" >> "$log_file"
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

    mkdir -p "${chillbox_state_home}/sites/${slugname}"
    dist_immutable_archive_file="$chillbox_state_home/sites/$slugname/$slugname-$version.immutable.tar.gz"
    dist_artifact_file="$chillbox_state_home/sites/$slugname/$slugname-$version.artifact.tar.gz"
    if [ -f "$dist_immutable_archive_file" ] && [ -f "$dist_artifact_file" ]; then
      {
      echo "The immutable archive file and site artifact file already exist:"
      echo "  $dist_immutable_archive_file"
      echo "  $dist_artifact_file"
      echo "Skipping the 'make' command for $slugname"
      } >> "$log_file"
      continue
    fi
    find "${chillbox_state_home}/sites/${slugname}" -type f \( -name "${slugname}-*.immutable.tar.gz" -o -name "${slugname}-*.artifact.tar.gz" \) -delete \
      || echo "No existing archive files to delete for ${slugname}" >> "$log_file"

    tmp_dir="$(mktemp -d)"
    mkdir -p "$tmp_dir/$slugname"
    tar x -f "$tmp_sites_dir/$release_filename" -C "$tmp_dir/$slugname" --strip-components=1
    chmod --recursive u+rw "$tmp_dir"

    echo "Running the 'make' command for $slugname which should make dist/immutable.tar.gz and dist/artifact.tar.gz" >> "$log_file"
    make --silent -C "$tmp_dir/$slugname" >> "$log_file"
    chmod --recursive u+rw "$tmp_dir"

    immutable_archive_file="$tmp_dir/$slugname/dist/immutable.tar.gz"
    test -f "$immutable_archive_file" || (echo "ERROR $script_name: No file at $immutable_archive_file" >> "$log_file" && exit 1)

    artifact_file="$tmp_dir/$slugname/dist/artifact.tar.gz"
    test -f "$artifact_file" || (echo "ERROR $script_name: No file at $artifact_file" >> "$log_file" && exit 1)

    echo "Saving the built files in the chillbox state directory for the $slugname site to avoid rebuilding the same version next time." >> "$log_file"
    test ! -f "$dist_immutable_archive_file" || rm -f "$dist_immutable_archive_file"
    mkdir -p "$(dirname "$dist_immutable_archive_file")"
    mv "$immutable_archive_file" "$dist_immutable_archive_file"
    test ! -f "$dist_artifact_file" || rm -f "$dist_artifact_file"
    mkdir -p "$(dirname "$dist_artifact_file")"
    mv "$artifact_file" "$dist_artifact_file"

    # Clean up
    rm -rf "$tmp_dir"

  done

  echo "Making a sites manifest json file at $sites_manifest_json_file" >> "$log_file"
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

# Output the json
jq --null-input \
  --arg jq_sites_artifact "$sites_artifact" \
  --arg jq_chillbox_artifact "$chillbox_artifact" \
  --arg jq_sites_manifest "$sites_manifest_json" \
  --arg jq_log_file "$log_file" \
  --argjson sites_immutable_and_artifacts "$(jq -r -c '.' "$sites_manifest_json_file")" \
  '{
    sites_artifact:$jq_sites_artifact,
    chillbox_artifact:$jq_chillbox_artifact,
    sites_manifest:$jq_sites_manifest,
    sites:$sites_immutable_and_artifacts,
    log_file:$jq_log_file
  }' > "$output_file"