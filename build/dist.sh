#!/usr/bin/env sh

set -o errexit
set -o nounset

working_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"

chillbox_cli_dist_file="$1"
chillbox_dist_dir="$(dirname "$chillbox_cli_dist_file")"
mkdir -p "$chillbox_dist_dir"

echo "Creating $chillbox_cli_dist_file from files listed in build/MANIFEST file."

if [ ! -f "$chillbox_cli_dist_file" ]; then
  tar c -z -f "$chillbox_cli_dist_file" \
    -C "$working_dir" \
    --verbatim-files-from \
    --files-from=build/MANIFEST
else
  echo "Chillbox CLI dist file already exists: $chillbox_cli_dist_file"
  exit 0
fi

