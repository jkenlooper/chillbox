#!/usr/bin/env sh

set -o errexit

cmd_that_needs_tty_owned_by_dev="$1"
test -n "$cmd_that_needs_tty_owned_by_dev" || (echo "ERROR $0: No arg passed in. First arg should be the command to execute as dev user" && exit 1)

current_user="$(id -u -n)"
test "$current_user" = "root" || (echo "ERROR $0: Must be root." && exit 1)

# Need to chown the tty before generating the gpg key since the user is being
# switched and gnupg pinentry requires the same permission.
chown dev "$(tty)"
cleanup() {
  chown root "$(tty)"
}
trap cleanup EXIT

su dev -c "$cmd_that_needs_tty_owned_by_dev"
