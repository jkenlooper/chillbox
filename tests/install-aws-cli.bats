#!/usr/bin/env bats

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/install-aws-cli.sh
}

@test "pass when aws cli v1 is installed" {
  run main
  assert_output --partial "aws-cli/1.19"
  assert_success
}
