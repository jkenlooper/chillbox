#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
  export TECH_EMAIL="test@example.com"
  export LETS_ENCRYPT_SERVER="letsencrypt_test"
  export ACME_SH_VERSION="3.0.1"
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
  "${BATS_TEST_DIRNAME}"/../bin/issue-and-install-letsencrypt-certs.sh
}

@test "fail when LETS_ENCRYPT_SERVER is empty" {
  export LETS_ENCRYPT_SERVER=""
  run main
  assert_failure
}
@test "fail when LETS_ENCRYPT_SERVER is not the test one" {
  export LETS_ENCRYPT_SERVER="llama"
  run main
  assert_failure
}

@test "pass when ..." {
  run main
  #assert_output --partial "Skipping 'acme.sh --install ...' step"
  assert_success
}
