#!/usr/bin/env bash
# Need to use bash since the 'wait' command from bash allows use of '-n' option.

set -o errexit

script_name="$(basename "$0")"

# The workers should be run with the site's slugname user.
# Protect against accidently running as root.
current_user="$(id -u -n)"
test "$current_user" != "root" || (echo "ERROR $script_name: Must not be root." && exit 1)
# TODO: Could also check that the current user is the slugname user?

count="$1"
run_cmd="$2"

# Sanity checks.
test -n "$count" || (echo "ERROR $script_name: The count arg (first arg) is empty." && exit 1)
test "$count" -gt "0" || (echo "ERROR $script_name: The count arg should be greater than 0." && exit 1)
test -n "$run_cmd" || (echo "ERROR $script_name: The run command arg (second arg) is empty." && exit 1)

# Cleanup
trap 'echo "INFO $script_name exit=$?: Clean up."' INT EXIT HUP

# Place bg processes in a subshell so the 'kill 0' trap will stop all of them
# when the parent script is stopped.
(
trap 'echo "INFO $script_name exit=$?: Stopping all workers." && kill 0' INT EXIT HUP
for w in $(seq 1 "$count"); do
  # Include CHILLBOX_WORKER variable to run command if it needs to select
  # different configuration based on the worker number.
  CHILLBOX_WORKER="$w" $run_cmd &
done

# Use '-n' on wait command to stop all bg processes as soon as one of them
# exits. This way the parent process can take action and potentially restart all
# workers.
wait -n
trap 'echo "INFO $script_name exit=$?: Worker exited."' INT EXIT HUP

# Last command is kill. Any other commands after this are not executed.
kill 0
)

# TODO: The 'kill 0' seems to always exit with the 128 + signal code, and
# 'Terminated' output, regardless of attempts to change the exit status.
