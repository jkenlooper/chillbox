#!/usr/bin/env bats

CRITICAL=50
DEBUG=10
ERROR=40
FATAL=50
INFO=20
NOTSET=0
WARN=30
WARNING=30
LOGGING_LEVEL=${LOGGING_LEVEL:-$WARNING}

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

  mock_python="$(mock_create)"
  ln -s "${mock_python}" $BATS_RUN_TMPDIR/python
  PATH="$BATS_RUN_TMPDIR:$PATH"
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock python symbolic link: $BATS_RUN_TMPDIR/python to $(readlink $BATS_RUN_TMPDIR/python)" >&3

  mock_pip="$(mock_create)"
  mock_flask="$(mock_create)"

}

teardown() {
  rm -rf  "/var/lib/site1"
	rm -f $slugdir/api.service_handler.json
	rm -f $slugdir/chill.service_handler.json
	rm -rf /var/lib/${slugname}/api
	rm -rf /var/lib/${slugname}/chill
	rm -rf /etc/services.d/${slugname}-api
	rm -rf /etc/services.d/${slugname}-chill

  rm -f $BATS_RUN_TMPDIR/python
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

@test "pass when service lang template is flask" {
  # Arrange
  export service_obj="$(jq -c '.services[0]' "${BATS_TEST_DIRNAME}"/fixtures/site1.site.json)"
  # Match up with site1.site.json
  export service_handler=api
  export service_name=api

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a venv $slugdir/$service_handler/.venv/bin" >&3
  mkdir -p $slugdir/$service_handler/.venv/bin
  ln -s "${mock_pip}" $slugdir/$service_handler/.venv/bin/pip
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock pip symbolic link: $slugdir/$service_handler/.venv/bin/pip to $(readlink $slugdir/$service_handler/.venv/bin/pip)" >&3
  ln -s "${mock_flask}" $slugdir/$service_handler/.venv/bin/flask
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock flask symbolic link: $slugdir/$service_handler/.venv/bin/flask to $(readlink $slugdir/$service_handler/.venv/bin/flask)" >&3

  # Act
  run main "${service_obj}"

  # Assert
  test "$(mock_get_call_num "${mock_python}")" -eq 1
  test "$(mock_get_call_num "${mock_pip}")" -eq 1
  test "$(mock_get_call_num "${mock_flask}")" -eq 1

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a $service_handler.service_handler.json" >&3
  test -f $slugdir/$service_handler.service_handler.json

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a /var/lib/${slugname}/${service_handler} directory" >&3
  test -d "/var/lib/${slugname}/${service_handler}"

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a /etc/services.d/${slugname}-${service_name}/run command" >&3
  test -d "/etc/services.d/${slugname}-${service_name}"
  test -f "/etc/services.d/${slugname}-${service_name}/run"

  assert_success
}


# TODO
# handle chill service
# show error if service not supported
