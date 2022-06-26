#!/usr/bin/env sh

set -o errexit

usage() {
  cat <<HERE
chillbox
Usage:
  $0 -h
  $0 <instance_name> [interactive | init | plan | apply | destroy | clean | pull | push]

Sub commands:
  interactive - Start containers in that mode.
  init - Create a new chillbox instance.
  plan, apply, destroy - Passed to the Terraform command inside each container.
  pull - Pulls the Terraform state files to the host.
  push - Pushes the Terraform state files to the Terraform containers.
  clean - Removes state files that were saved for the instance and workspace.
HERE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done


echo "TODO"
