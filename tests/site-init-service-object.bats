#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
  export slugname="site1"

  adduser -D -h /dev/null -H "$slugname" || printf "Ignoring adduser error"

  tmp_dir=$(mktemp -d)
  export tmp_artifact=$tmp_dir/site1-artifact.tar.gz
  "${BATS_TEST_DIRNAME}"/fixtures/site1/bin/artifact.sh $tmp_artifact

  export service_obj="$(jq -c '.services[0]' "${BATS_TEST_DIRNAME}"/fixtures/sites/site1.site.json)"

  export slugdir="$tmp_dir/usr/local/src/$slugname"
  mkdir -p "$slugdir"

  mkdir -p /var/lib/chillbox-shared-secrets/$slugname
  touch /var/lib/chillbox-shared-secrets/$slugname/api.cfg

  export S3_ARTIFACT_ENDPOINT_URL="http://fake.s3.endpoint.test"
  export S3_ENDPOINT_URL="http://fake.s3.endpoint.test"
  export ARTIFACT_BUCKET_NAME="fake-artifact-bucket"
  export IMMUTABLE_BUCKET_NAME="fake-immutable-bucket"

  "${BATS_TEST_DIRNAME}"/../bin/create-env_names-file.sh
}
teardown_file() {
  rm -f /etc/chillbox/env_names
  test -d "$tmp_dir" && rm -rf $tmp_dir

  rm /var/lib/chillbox-shared-secrets/$slugname/api.cfg
  rmdir /var/lib/chillbox-shared-secrets/$slugname
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
  load '/opt/bats-mock/load'

  mock_python="$(mock_create)"
  ln -s "${mock_python}" $BATS_RUN_TMPDIR/python
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock python symbolic link: $BATS_RUN_TMPDIR/python to $(readlink $BATS_RUN_TMPDIR/python)" >&3

  mock_chill="$(mock_create)"
  # The chill command is executed with su -c which doesn't work in the tests. As
  # a workaround, set the chill executable directly in the existing PATH.
  ln -s "${mock_chill}" /usr/local/bin/chill
  # Allow any user to write to the call_num file
  chmod a+w ${mock_chill}.call_num

  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock chill symbolic link: /usr/local/bin/chill to $(readlink /usr/local/bin/chill)" >&3
  #chmod +x $mock_chill $BATS_RUN_TMPDIR/chill
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock chill symbolic link: $(ls -al /usr/local/bin/chill $(readlink /usr/local/bin/chill))" >&3
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# mock chill: $(ls -al ${mock_chill}*)" >&3

  mock_pip="$(mock_create)"
  mock_flask="$(mock_create)"

  PATH="$BATS_RUN_TMPDIR:$PATH"
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
  rm -f /usr/local/bin/chill
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
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "fail when slugname is empty" {
  export slugname=""
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "fail when slugdir is empty" {
  export slugdir=""
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "fail when S3_ARTIFACT_ENDPOINT_URL is empty" {
  export S3_ARTIFACT_ENDPOINT_URL=""
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "fail when S3_ENDPOINT_URL is empty" {
  export S3_ENDPOINT_URL=""
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "fail when ARTIFACT_BUCKET_NAME is empty" {
  export ARTIFACT_BUCKET_NAME=""
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "fail when IMMUTABLE_BUCKET_NAME is empty" {
  export IMMUTABLE_BUCKET_NAME=""
  run main "${service_obj}" "${tmp_artifact}"
  assert_failure
}

@test "pass when service lang template is flask" {
  # Arrange
  export service_obj="$(jq -c '.services[0]' "${BATS_TEST_DIRNAME}"/fixtures/sites/site1.site.json)"
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
  run main "${service_obj}" "${tmp_artifact}"

  # Assert
  assert_success

  test "$(mock_get_call_num "${mock_python}")" -eq 1
  test "$(mock_get_call_num "${mock_chill}")" -eq 0
  test "$(mock_get_call_num "${mock_pip}")" -eq 1
  test "$(mock_get_call_num "${mock_flask}")" -eq 1

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a $service_handler.service_handler.json" >&3
  test -f $slugdir/$service_handler.service_handler.json

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a /var/lib/${slugname}/${service_handler} directory" >&3
  test -d "/var/lib/${slugname}/${service_handler}"

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a /etc/services.d/${slugname}-${service_name}/run command" >&3
  test -d "/etc/services.d/${slugname}-${service_name}"
  test -f "/etc/services.d/${slugname}-${service_name}/run"
}


@test "pass when service lang template is chill and freeze is true" {
  # Arrange
  export service_obj="$(jq -c '.services[1]' "${BATS_TEST_DIRNAME}"/fixtures/sites/site1.site.json)"
  # Match up with site1.site.json
  export service_handler=chill
  export service_name=chillstatic

  # Act
  run main "${service_obj}" "${tmp_artifact}"

  # Assert
  assert_success

  test "$(mock_get_call_num "${mock_python}")" -eq 0
  test "$(mock_get_call_num "${mock_chill}")" -eq 3

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a $service_handler.service_handler.json" >&3
  test -f $slugdir/$service_handler.service_handler.json

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a /etc/services.d/${slugname}-${service_name}/run command" >&3
  test ! -d "/etc/services.d/${slugname}-${service_name}"
  test ! -f "/etc/services.d/${slugname}-${service_name}/run"
}

@test "pass when service lang template is chill and freeze is false" {
  # Arrange
  export service_obj="$(jq -c '.services[2]' "${BATS_TEST_DIRNAME}"/fixtures/sites/site1.site.json)"
  # Match up with site1.site.json
  export service_handler=chill
  export service_name=chilldynamic

  # Act
  run main "${service_obj}" "${tmp_artifact}"

  # Assert
  assert_success

  test "$(mock_get_call_num "${mock_python}")" -eq 0
  test "$(mock_get_call_num "${mock_chill}")" -eq 2

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a $service_handler.service_handler.json" >&3
  test -f $slugdir/$service_handler.service_handler.json

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a /etc/services.d/${slugname}-${service_name}/run command" >&3
  test -d "/etc/services.d/${slugname}-${service_name}"
  test -f "/etc/services.d/${slugname}-${service_name}/run"
}
