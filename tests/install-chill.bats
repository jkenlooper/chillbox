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
  test "${status}" -ne 0
}

@test "pass when PIP_CHILL is set" {
  export PIP_CHILL="chill"
  run main
  # TODO
  assert_output "chicken"
  test "${status}" -eq 1
}
