#!/usr/bin/env bats

# shellcheck disable=SC1090
. "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  command -v gpg || apk add gnupg gnupg-dirmngr
  test "${LOGGING_LEVEL}" -le "$WARNING" && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'

  # Use an ephemeral directory for gpg home for testing
  tmp_gpg_home="$(mktemp -d)"
  export GNUPGHOME="$tmp_gpg_home"
}
teardown() {
  rm -rf "$tmp_gpg_home"
}

main() {
  CHILLBOX_GPG_PASSPHRASE="test" "${BATS_TEST_DIRNAME}"/../bin/generate-chillbox-key.sh
}

@test "pass when chillbox gpg key is generated" {
  run main
  gpg --list-keys chillbox
  assert_success
}
