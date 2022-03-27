#!/usr/bin/env bats

setup_file() {
  export slugname="site1"

  adduser -D -h /dev/null -H "$slugname" || printf "Ignoring adduser error"

  tmp_dir=$(mktemp -d)
  export tmp_artifact=$tmp_dir/site1-artifact.tar.gz
  "${BATS_TEST_DIRNAME}"/fixtures/site1/bin/artifact.sh $tmp_artifact

  export service_obj="$(jq -c '.services[0]' "${BATS_TEST_DIRNAME}"/fixtures/site1.site.json)"

  export slugdir="$tmp_dir/usr/local/src/$slugname"
  mkdir -p "$slugdir"

  export S3_ARTIFACT_ENDPOINT_URL="http://fake.s3.endpoint.test"
  export S3_ENDPOINT_URL="http://fake.s3.endpoint.test"
  export ARTIFACT_BUCKET_NAME="fake-artifact-bucket"
  export IMMUTABLE_BUCKET_NAME="fake-immutable-bucket"

  "${BATS_TEST_DIRNAME}"/../bin/create-env_names-file.sh
}
teardown_file() {
  rm -f /etc/chillbox/env_names
  test -d "$tmp_dir" && echo " rm -rf $tmp_dir"
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
  load '/opt/bats-mock/load'

  #DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ## make executables in . visible to PATH
  #export PATH="$DIR:$PATH"
}

teardown() {
  rm -rf  "/var/lib/site1"
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh $@
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
  # Match up with site1.site.json
  export service_handler=api
  export service_name=api

  mock_python="$(mock_create)"
  ln -s "${mock_python}" $BATS_RUN_TMPDIR/python
  PATH="$BATS_RUN_TMPDIR:$PATH"
  #echo "# Creates a mock python $mock_python" >&3
  #echo "# $PATH" >&3

  mock_pip="$(mock_create)"
  mock_flask="$(mock_create)"

  #echo "# Creates a venv $slugdir/$service_handler/.venv/bin" >&3
  mkdir -p $slugdir/$service_handler/.venv/bin
  ln -s "${mock_pip}" $slugdir/$service_handler/.venv/bin/pip
  ln -s "${mock_flask}" $slugdir/$service_handler/.venv/bin/flask

  run main "${service_obj}"
  test "$(mock_get_call_num "${mock_python}")" -eq 1
  test "$(mock_get_call_num "${mock_pip}")" -eq 1
  test "$(mock_get_call_num "${mock_flask}")" -eq 1

  echo "# Creates a $service_handler.service_handler.json" >&3
  test -f $slugdir/$service_handler.service_handler.json

  echo "# Creates a /var/lib/${slugname}/${service_handler} directory" >&3
  test -d "/var/lib/${slugname}/${service_handler}"

  echo "# Creates a /etc/services.d/${slugname}-${service_name}/run command" >&3
  test -d "/etc/services.d/${slugname}-${service_name}"
  test -f "/etc/services.d/${slugname}-${service_name}/run"


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
