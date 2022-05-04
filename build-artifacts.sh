#!/usr/bin/env bash

set -o errexit

working_dir=$(realpath $(dirname $0))

# Need to use a log file for stdout since the stdout could be parsed as JSON by
# terraform external data source.
LOG_FILE="$working_dir/$0.log"
echo $(date) > $LOG_FILE

showlog () {
  # Terraform external data will need to echo to stderr to show the message to
  # the user.
  >&2 echo "See log file: $LOG_FILE for further details."
  cat $LOG_FILE
}
trap showlog err

# Extract and set shell variables from JSON input
eval "$(jq -r '@sh "
  sites_git_repo=\(.sites_git_repo)
  sites_git_branch=\(.sites_git_branch)
  "')"

echo "set shell variables from JSON stdin" >> $LOG_FILE
echo "  sites_git_repo=$sites_git_repo" >> $LOG_FILE
echo "  sites_git_branch=$sites_git_branch" >> $LOG_FILE

CHILLBOX_ARTIFACT=chillbox.$(cat VERSION).tar.gz
echo "CHILLBOX_ARTIFACT=$CHILLBOX_ARTIFACT" >> $LOG_FILE

# TODO Skip creating any changes to the dist directory to prevent unecessary
# docker build of 020 infra.

tmp_sites_dir=$(mktemp -d)
# TODO Change to be a zip of the source code files instead of depending on git.
echo "Cloning $sites_git_repo $sites_git_branch to tmp dir: $tmp_sites_dir" >> $LOG_FILE
git clone --depth 1 --single-branch --branch "$sites_git_branch" $sites_git_repo $tmp_sites_dir
cd $tmp_sites_dir

sites_commit_id=$(git rev-parse --short HEAD)
SITES_ARTIFACT=$(basename ${sites_git_repo%.git})-$sites_git_branch-$sites_commit_id.tar.gz
echo "SITES_ARTIFACT=$SITES_ARTIFACT" >> $LOG_FILE

mkdir -p "$working_dir/dist"

# Create the chillbox artifact file
if [ ! -f "$working_dir/dist/$CHILLBOX_ARTIFACT" ]; then
  cd $working_dir
  tar -c -z -f "$working_dir/dist/$CHILLBOX_ARTIFACT" \
    default.nginx.conf \
    nginx.conf \
    templates \
    bin \
    VERSION
else
  echo "No changes to existing chillbox artifact: $CHILLBOX_ARTIFACT" >> $LOG_FILE
fi

# Create the sites artifact file

cd $tmp_sites_dir

sites=$(find sites -type f -name '*.site.json')

echo $sites >> $LOG_FILE

for site_json in $sites; do
  cd $tmp_sites_dir
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  echo $slugname >> $LOG_FILE

  # TODO Validate the site_json file https://github.com/marksparkza/jschon

  version="$(jq -r '.version' $site_json)"

  dist_immutable_archive_file="$working_dir/dist/$slugname/$slugname-$version.immutable.tar.gz"
  dist_artifact_file="$working_dir/dist/$slugname/$slugname-$version.artifact.tar.gz"
  if [ -f $dist_immutable_archive_file ] && [ -f "$dist_artifact_file" ]; then
    echo "Skipping the 'make' command for $slugname" >> $LOG_FILE
    continue
  fi

  tmp_dir=$(mktemp -d)
  git_repo="$(jq -r '.git_repo' $site_json)"
  # TODO Change to be a zip of the source code files instead of depending on git.
  git clone --depth 1 --single-branch --branch "$version" --recurse-submodules $git_repo $tmp_dir >> $LOG_FILE
  cd $tmp_dir
  echo "Running the 'make' command for $slugname" >> $LOG_FILE
  make >> $LOG_FILE

  immutable_archive_file=$tmp_dir/$slugname-$version.immutable.tar.gz
  test -f $immutable_archive_file || (echo "No file at $immutable_archive_file" >> $LOG_FILE && exit 1)

  artifact_file=$tmp_dir/$slugname-$version.artifact.tar.gz
  test -f $artifact_file || (echo "No file at $artifact_file" >> $LOG_FILE && exit 1)

  test ! -f "$dist_immutable_archive_file" || rm -f "$dist_immutable_archive_file"
  mkdir -p $(dirname "$dist_immutable_archive_file")
  mv $immutable_archive_file "$dist_immutable_archive_file"
  test ! -f "$dist_artifact_file" || rm -f "$dist_artifact_file"
  mkdir -p $(dirname "$dist_artifact_file")
  mv $artifact_file "$dist_artifact_file"

done


cd $tmp_sites_dir
tar -c -z -f "$working_dir/dist/$SITES_ARTIFACT" sites >> $LOG_FILE

echo "SITES_ARTIFACT=$SITES_ARTIFACT" >> $LOG_FILE

# Make a sites manifest json file
sites_manifest_json="dist/sites.manifest.json"
cd $tmp_sites_dir
tmp_file_list=$(mktemp)
sites=$(find sites -type f -name '*.site.json')
for site_json in $sites; do
  cd $tmp_sites_dir
  slugname=${site_json%.site.json}
  slugname=${slugname#sites/}
  version="$(jq -r '.version' $site_json)"
  echo "$slugname/$slugname-$version.immutable.tar.gz" >> $tmp_file_list
  echo "$slugname/$slugname-$version.artifact.tar.gz" >> $tmp_file_list
done
cat $tmp_file_list | xargs jq --null-input --args '$ARGS.positional' > "$working_dir/$sites_manifest_json"
rm -f $tmp_file_list

# Output the json
jq --null-input \
  --arg sites_artifact "$SITES_ARTIFACT" \
  --arg chillbox_artifact "$CHILLBOX_ARTIFACT" \
  --arg jq_sites_manifest "$sites_manifest_json" \
  --argjson sites_immutable_and_artifacts "$(jq -r -c '.' $working_dir/$sites_manifest_json)" \
  '{
    sites_artifact:$sites_artifact,
    chillbox_artifact:$chillbox_artifact,
    sites_manifest:$jq_sites_manifest,
    sites:$sites_immutable_and_artifacts
  }'
