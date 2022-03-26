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
  load '/opt/bats-mock/load'
}
#teardown() {
#}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/site-init.sh
}

something_that_call_curl() {
  curl --version
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
# skips versions that have already been deployed
# stops services and makes backups
# extracts site nginx service
# extracts each service listed in site json
# handle flask service
# handle chill service
# show error if service not supported
# set crontab
# set site root dir, version.txt for nginx
@test "pass when ..." {
  run main
  assert_success
}

# FIXTURES
# SITES_ARTIFACT
# $slugname-$version.artifact.tar.gz
# /etc/chillbox/env_names

# MOCKS
# aws
# rc-service
# rc-update
# python
# ./.venv/bin/pip
# ./.venv/bin/flask
# su or chill ?

@test "my override test" {
  mock_curl="$(mock_create)"
  curl() {
    "${mock_curl}" "$@"
  }
  run something_that_call_curl
  [ "$(mock_get_call_num "${mock_curl}")" -eq 1 ]
}
