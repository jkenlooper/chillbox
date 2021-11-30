#!/bin/env sh

set -o errexit

bin_dir=$(dirname $(realpath $0))
source $bin_dir/common-functions.sh
while getopts ":h" opt; do
  case ${opt} in
    h )
      usage_generic_ansible_playbook;
      ;;
    \? )
      usage_generic_ansible_playbook;
      ;;
  esac;
done;
shift "$((OPTIND-1))";
ENVIRONMENT=${1-$ENVIRONMENT}
test -z "$ENVIRONMENT" && usage_generic_ansible_playbook

set -o nounset

echo "
Deploy artifact to chill box.
"

check_environment_variable $ENVIRONMENT

echo "

Executing Ansible playbook: ansible-playbooks/$(basename ${0%.sh}.yml

"

# How does it know which site to deploy?
# chill box nginx should serve just the VERSION file for each site.
# deploy.sh goes through each site and checks if the version matches the one on
# the chillbox host?

./upload-version.sh

# - Upload all files in immutable directory to a versioned path.
# - Delete previous artifact tar.gz from S3 if applicable
# - Upload artifact tar.gz to S3

# On remote chillbox host (only read access to S3)
# - Download artifact tar.gz from S3
# - Expand to new directory for the version
# - chill init, load yaml
# - add and enable, start the systemd service for new version
# - stage the new version by updating NGINX environment variables
# - run integration tests on staged version
# - promote the staged version to production by updating NGINX environment variables
# - remove old version

# On local
# - Delete old immutable versioned path on S3

# Prompt for the artifact file to use.
versioned_artifact_file=puzzle-massive-$(jq -r '.version' ../package.json).tar.gz
latest_artifact_file=$(find ../ -maxdepth 1 -name $versioned_artifact_file)
example=""
if [ -z "$latest_artifact_file" ]; then
  latest_artifact_file=$(find ../ -maxdepth 1 -name 'puzzle-massive-*.tar.gz' | head -n1)
  if [ -z "$latest_artifact_file" ]; then
    example=' (Create one with the `make artifact` command)'
  fi
fi
DIST_FILE=$(read -e -p "
Use artifact file:
${example}
" -i "$latest_artifact_file" && echo $REPLY)
DIST_FILE=$(realpath $DIST_FILE)
test -e $DIST_FILE || (echo "No file at $DIST_FILE" && exit 1)

ansible-playbook ansible-playbooks/in-place-quick-deploy.yml \
 -u dev \
 -i $ENVIRONMENT/host_inventory.ansible.cfg \
 --ask-become-pass \
 --extra-vars "message_file=../$ENVIRONMENT/puzzle-massive-message.html
 artifact_file=$DIST_FILE
 makeenvironment=$(test $ENVIRONMENT = 'development' && echo 'development' || echo 'production')"

