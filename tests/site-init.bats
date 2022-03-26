#!/usr/bin/env bats

setup_file() {
  export S3_ARTIFACT_ENDPOINT_URL="TODO"
  export ARTIFACT_BUCKET_NAME="TODO"
  export SITES_ARTIFACT="TODO"
  export CHILLBOX_SERVER_PORT="TODO"
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
}
#teardown() {
#}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/site-init.sh
}

@test "fail when S3_ARTIFACT_ENDPOINT_URL is empty" {
  export S3_ARTIFACT_ENDPOINT_URL=""
  run main
  assert_failure
}

@test "fail when ARTIFACT_BUCKET_NAME is empty" {
  export ARTIFACT_BUCKET_NAME=""
  run main
  assert_failure
}

@test "fail when SITES_ARTIFACT is empty" {
  export SITES_ARTIFACT=""
  run main
  assert_failure
}

@test "fail when CHILLBOX_SERVER_PORT is empty" {
  export CHILLBOX_SERVER_PORT=""
  run main
  assert_failure
}

# TODO
@test "pass when ..." {
  run main
  assert_success
}
