#!/usr/bin/env sh
set -o errexit

count="$1"
run_cmd="$2"

# Place bg processes in a subshell so the 'kill 0' trap will stop all of them
# when the parent script is stopped.
(
trap 'kill 0' INT EXIT HUP
for f in $(seq 1 $count); do
  $2 &
done

wait
)
