#!/usr/bin/env bats

setup_file() {
  # TODO create tar for site

  export service_obj="TODO"
  export tmp_artifact=" $slugname-$version.artifact.tar.gz"
  export slugname="TODO"
  export slugdir="TODO"
  export S3_ARTIFACT_ENDPOINT_URL="TODO"
  export S3_ENDPOINT_URL="TODO"
  export ARTIFACT_BUCKET_NAME="TODO"
  export IMMUTABLE_BUCKET_NAME="TODO"

  "${BATS_TEST_DIRNAME}"/../bin/create-env_names-file.sh
}
teardown_file() {
  rm -f /etc/chillbox/env_names
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
  load '/opt/bats-mock/load'
}
#teardown() {
#}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh $@
}

something_that_call_curl() {
  curl --version
}

@test "fail when service_obj is empty" {
  service_obj=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when tmp_artifact is empty" {
  export tmp_artifact=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when slugname is empty" {
  export slugname=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when slugdir is empty" {
  export slugdir=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when S3_ARTIFACT_ENDPOINT_URL is empty" {
  export S3_ARTIFACT_ENDPOINT_URL=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when S3_ENDPOINT_URL is empty" {
  export S3_ENDPOINT_URL=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when ARTIFACT_BUCKET_NAME is empty" {
  export ARTIFACT_BUCKET_NAME=""
  run main "${service_obj}"
  assert_failure
}

@test "fail when IMMUTABLE_BUCKET_NAME is empty" {
  export IMMUTABLE_BUCKET_NAME=""
  run main "${service_obj}"
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
  run main "${service_obj}"
  assert_success
}

# FIXTURES
# tmp_artifact = $slugname-$version.artifact.tar.gz
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
