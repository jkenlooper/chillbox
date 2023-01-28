#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

cmd_that_needs_tty_owned_by_dev="$1"
test -n "$cmd_that_needs_tty_owned_by_dev" || (echo "ERROR $script_name: No arg passed in. First arg should be the command to execute as dev user" && exit 1)

current_user="$(id -u -n)"
test "$current_user" = "root" || (echo "ERROR $script_name: Must be root." && exit 1)

# Need to chown the tty before generating the gpg key since the user is being
# switched and gnupg pinentry requires the same permission.
#current_tty="$(tty)"
# TODO Why does the tty command sometimes return 'not a tty'?
chown dev "$(tty)"
cleanup() {
  chown root "$(tty)"
}
trap cleanup EXIT

su dev -c "$cmd_that_needs_tty_owned_by_dev"
