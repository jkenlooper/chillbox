#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
}

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
