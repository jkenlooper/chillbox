#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
  export TECH_EMAIL="test@example.com"
  export LETS_ENCRYPT_SERVER="letsencrypt_test"
  export ACME_SH_VERSION="3.0.1"
  export SKIP_INSTALL_ACMESH="y"

  mkdir -p /etc/chillbox/
  cp -R "${BATS_TEST_DIRNAME}"/fixtures/sites /etc/chillbox/
}
teardown_file() {
  rm -rf /etc/chillbox/sites
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
  load '/opt/bats-mock/load'

  mock_acmesh="$(mock_create)"
  ln -s "${mock_acmesh}" $BATS_RUN_TMPDIR/acme.sh

  PATH="$BATS_RUN_TMPDIR:$PATH"
}
teardown() {
  rm -rf /var/lib/acmesh

  test -L $BATS_RUN_TMPDIR/acme.sh \
    && rm -f $BATS_RUN_TMPDIR/acme.sh
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

@test "pass when acme.sh is called to issue and install cert for each site" {
  run main
  assert_success

  test "$(mock_get_call_num "${mock_acmesh}")" -eq 2
}
