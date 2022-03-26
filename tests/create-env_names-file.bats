#!/usr/bin/env bats

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
}
teardown() {
  rm -f /etc/chillbox/env_names
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/create-env_names-file.sh
}

@test "pass when /etc/chillbox/env_names file is created" {
  run main
  test -f /etc/chillbox/env_names
  assert_success
}
