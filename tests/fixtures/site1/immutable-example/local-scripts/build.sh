#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
invalid_errcode=4

usage() {
  cat <<HEREUSAGE

Build script to create files in the dist directory by processing the files in
a src directory.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

Environment Variables:
  BUILD_SRC_DIR=/build/src
  BUILD_DIST_DIR=/build/dist


HEREUSAGE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit "$invalid_errcode" ;;
  esac
done
shift $((OPTIND - 1))

check_for_required_commands() {
  # This simple example only requires commands that are probably already part of
  # the system (realpath, cp, find).
  for required_command in \
    realpath \
    cp \
    find \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit "$invalid_errcode")
  done
}

check_env_vars() {
  test -n "$BUILD_SRC_DIR" || (echo "ERROR $script_name: No BUILD_SRC_DIR environment variable defined" >&2 && usage && exit "$invalid_errcode")
  test -d "$BUILD_SRC_DIR" || (echo "ERROR $script_name: The BUILD_SRC_DIR environment variable is not set to a directory" >&2 && usage && exit "$invalid_errcode")

  test -n "$BUILD_DIST_DIR" || (echo "ERROR $script_name: No BUILD_DIST_DIR environment variable defined" >&2 && usage && exit "$invalid_errcode")
}

check_for_required_commands
check_env_vars

build_it() {
  # For this example it is only copying the files from the src directory to the
  # dist directory.
  if [ -d "$BUILD_DIST_DIR" ]; then
    # Start with a fresh dist directory.
    find "$BUILD_DIST_DIR" -depth -mindepth 1 -type f -delete
    find "$BUILD_DIST_DIR" -depth -mindepth 1 -type d -empty -delete
  else
    mkdir -p "$BUILD_DIST_DIR"
  fi
  find "$BUILD_SRC_DIR" -depth -mindepth 1 -maxdepth 1 -exec cp -Rf {} "$BUILD_DIST_DIR/" \;
}
build_it
