#!/usr/bin/env sh

set -o errexit

# The manifest file will include every file in the project that is needed to run
# the deployment scripts. It does not include extra documentation or tests.

working_dir="$(realpath "$(dirname "$(dirname "$(realpath "$0")")")")"

cd "$working_dir"

# The output of this script should *only* be the list of files since the stdout
# is read in by other commands.
find . \
  -type f \
  \! -path './.git/*' \
  \! -path './.github/*' \
  \! -name '.gitkeep' \
  \! -path './.pip-audit-last-run.txt' \
  \( \
    -path './bin/*' \
    -o -path './dep/*' \
    -o -path './nginx/*' \
    -o -path './redis/*' \
    -o -path './terraform/*' \
    -o -path './README.md' \
    -o -path './LICENSE' \
  \) \
  | sort
