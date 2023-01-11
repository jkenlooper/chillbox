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
  "${BATS_TEST_DIRNAME}"/../bin/install-chill.sh
}

@test "pass when chill can be installed" {
  run main
  assert_output --partial "Installing chill version"
  # The python version is 3.9 because the base image for bats/bats-core uses the
  # docker 'bash:latest' base image which is alpine 3.15. Alpine 3.15 uses
  # python 3.9. Only check that at least python 3 has been installed.
  assert_output --partial "Python 3"
  assert_output --partial "Chill 0.10."
  assert_success
}

@test "pass when chill can be installed a second time" {
  run main
  assert_output --partial "Skipping reinstall of chill version"
  assert_output --partial "Python 3"
  assert_output --partial "Chill 0.10."
  assert_success
}
