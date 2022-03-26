#!/usr/bin/env bats

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/install-service-dependencies.sh
}

@test "pass when service dependencies are installed" {
  run main
  assert_output --partial "Finished"
  assert_success
}
