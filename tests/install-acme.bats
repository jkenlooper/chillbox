#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
  export TECH_EMAIL="test@example.com"
  export ACME_SERVER="letsencrypt_test"
  export SKIP_INSTALL_ACMESH="y"
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
}
teardown() {
  rm -rf /usr/local/bin/acme.sh
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/install-acme.sh
}

@test "fail when TECH_EMAIL is empty" {
  export TECH_EMAIL=""
  run main
  assert_failure
}

@test "fail when ACME_SERVER is empty" {
  export ACME_SERVER=""
  run main
  assert_failure
}

@test "pass when acme.sh can be installed, but skip the actual install step" {
  run main
  assert_output --partial "acme.sh version: https://github.com/acmesh-official/acme.sh v3.0.4"
  assert_output --partial "Skipping 'acme.sh --install ...' step"
  assert_success
}
