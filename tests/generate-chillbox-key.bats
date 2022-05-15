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
  load '/opt/bats-mock/load'

  mock_aws="$(mock_create)"
  mock_set_output "${mock_aws}" "something" 0
  ln -s "${mock_aws}" $BATS_RUN_TMPDIR/aws

  PATH="$BATS_RUN_TMPDIR:$PATH"

  # Use an ephemeral directory for gpg home for testing
  tmp_gpg_home="$(mktemp -d)"
  export GNUPGHOME="$tmp_gpg_home"
  export S3_ARTIFACT_ENDPOINT_URL="test"
  export ARTIFACT_BUCKET_NAME="test"
  export AWS_PROFILE="test"
}
teardown() {
  rm -rf "$tmp_gpg_home"

  test -L $BATS_RUN_TMPDIR/aws \
    && rm -f $BATS_RUN_TMPDIR/aws
}

main() {
  CHILLBOX_GPG_PASSPHRASE="test" "${BATS_TEST_DIRNAME}"/../bin/generate-chillbox-key.sh
}

@test "pass when chillbox gpg key is generated" {
  run main
  assert_success

  test "$(mock_get_call_num "${mock_aws}")" -eq 1
}
