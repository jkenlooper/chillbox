#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3
  export SLUGNAME="site1"

  tmp_dir=$(mktemp -d)

  export slugdir="$tmp_dir/usr/local/src/$SLUGNAME"
  mkdir -p "$slugdir"

  mkdir -p /etc/chillbox/sites
  cp -f "${BATS_TEST_DIRNAME}/fixtures/sites/site1.site.json" /etc/chillbox/sites/

  export S3_ARTIFACT_ENDPOINT_URL="http://fake.s3.endpoint.test"
  export S3_ENDPOINT_URL="http://fake.s3.endpoint.test"
  export ARTIFACT_BUCKET_NAME="fake-artifact-bucket"
  export IMMUTABLE_BUCKET_NAME="fake-immutable-bucket"
  export CHILLBOX_GPG_KEY_NAME="chillbox-test"

  export CHILLBOX_SERVER_NAME="chillbox"
  export CHILLBOX_SERVER_PORT="80"
  export IMMUTABLE_BUCKET_DOMAIN_NAME="https://chum.bucket.test"
  export SLUGNAME="site1"
  export VERSION="1.2.3"
  export SERVER_NAME="chillbox-test"
  export SERVER_PORT="80"
}

teardown_file() {
  test -d "$tmp_dir" && rm -rf $tmp_dir
  rm -f /etc/chillbox/sites/site1.site.json
}

setup() {
  load '/opt/bats-support/load'
  load '/opt/bats-assert/load'
  load '/opt/bats-mock/load'


  mock_rc_service="$(mock_create)"
  ln -s "${mock_rc_service}" $BATS_RUN_TMPDIR/rc-service
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock rc-service symbolic link: $BATS_RUN_TMPDIR/rc-service to $(readlink $BATS_RUN_TMPDIR/rc-service)" >&3

  mock_rc_update="$(mock_create)"
  ln -s "${mock_rc_update}" $BATS_RUN_TMPDIR/rc-update
  test "${LOGGING_LEVEL}" -le $DEBUG \
    && echo "# Creates a mock rc-update symbolic link: $BATS_RUN_TMPDIR/rc-update to $(readlink $BATS_RUN_TMPDIR/rc-update)" >&3

  service_obj="$(jq -c '.services[0]' "${BATS_TEST_DIRNAME}"/fixtures/sites/site1.site.json)"
  # Make an existing service handler dir and json file
  echo $service_obj | jq -c '.' > $slugdir/api.service_handler.json
  mkdir -p $slugdir/api
  touch $slugdir/api/fake-file1
  touch $slugdir/api/fake-file2

  PATH="$BATS_RUN_TMPDIR:$PATH"
}

teardown() {
	rm -f $slugdir/api.service_handler.json
	rm -f $slugdir/api.service_handler.json.bak
  rm -f $slugdir/api.bak.tar.gz
  rm -f /var/lib/${SLUGNAME}/secrets/api.cfg.bak

  rm -f $BATS_RUN_TMPDIR/rc-service
  rm -f $BATS_RUN_TMPDIR/rc-update
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh $@
}

@test "fail when SLUGNAME is empty" {
  export SLUGNAME=""
  run main
  assert_failure
}

@test "fail when slugdir is empty" {
  export slugdir=""
  run main
  assert_failure
}

@test "fail when slugdir is not a directory" {
  touch "$tmp_dir/file1"
  export slugdir="$tmp_dir/file1"
  run main
  assert_failure
}

@test "fail when slugdir parent is not a directory" {
  export slugdir="/"
  run main
  assert_failure
}

@test "fail when slugdir is not an absolute path" {
  export slugdir="./"
  run main
  assert_failure
}

@test "pass when stops services and creates backups" {
  # Arrange

  # Act
  run main

  # Assert
  assert_success

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Calls rc-service and rc-update" >&3
  test "$(mock_get_call_num "${mock_rc_service}")" -eq 1
  test "$(mock_get_call_num "${mock_rc_update}")" -eq 1

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a backup $slugdir/api.service_handler.json.bak" >&3
  test -f $slugdir/api.service_handler.json.bak

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates a backup $slugdir/api.bak.tar.gz" >&3
  test -f $slugdir/api.bak.tar.gz

}
