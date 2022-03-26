#!/usr/bin/env bats

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/install-chill.sh
}

@test "fail when PIP_CHILL is empty" {
  export PIP_CHILL=""
  run main
  echo "$output"
  assert_failure
}

@test "pass when PIP_CHILL is set and chill can be installed" {
  export PIP_CHILL="git+https://github.com/jkenlooper/chill.git@develop#egg=chill"
  run main
  assert_output --partial "Installing chill version"
  assert_output --partial "Python 3.9.7"
  assert_output --partial "Chill 0.9.0"
  assert_success
}
