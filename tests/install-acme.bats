#!/usr/bin/env bats

setup_file() {
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
  "${BATS_TEST_DIRNAME}"/../bin/install-acme.sh
}

@test "fail when TECH_EMAIL is empty" {
  export TECH_EMAIL=""
  run main
  assert_failure
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

@test "fail when ACME_SH_VERSION is empty" {
  export ACME_SH_VERSION=""
  run main
  assert_failure
}

@test "pass when acme.sh can be installed, but skip the actual install step" {
  run main
  assert_output --partial "acme.sh version: https://github.com/acmesh-official/acme.sh v3.0.1"
  assert_output --partial "Skipping 'acme.sh --install ...' step"
  assert_success
}
