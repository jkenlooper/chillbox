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

  mkdir -p /usr/local/src

  tmp_dir=$(mktemp -d)
  export tmp_artifact=$tmp_dir/site1-artifact.tar.gz
  "${BATS_TEST_DIRNAME}"/fixtures/site1/bin/artifact.sh $tmp_artifact

  export S3_ARTIFACT_ENDPOINT_URL="TODO"
  export ARTIFACT_BUCKET_NAME="TODO"
  export SITES_ARTIFACT="TODO"
  export CHILLBOX_SERVER_PORT="TODO"

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

  mock_stop_site_services_sh="$(mock_create)"
  mv "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh.bak
  ln -s "${mock_stop_site_services_sh}" "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh

  mock_site_init_nginx_service_sh="$(mock_create)"
  mv "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh.bak
  ln -s "${mock_site_init_nginx_service_sh}" "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh

  mock_site_init_service_object_sh="$(mock_create)"
  mv "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh.bak
  ln -s "${mock_site_init_service_object_sh}" "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh

  mock_aws="$(mock_create)"
  ln -s "${mock_aws}" $BATS_RUN_TMPDIR/aws

  PATH="$BATS_RUN_TMPDIR:$PATH"
}

teardown() {
  test -L "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh \
    && rm "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh
  test -e "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh.bak \
    && mv "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh.bak "${BATS_TEST_DIRNAME}"/../bin/stop-site-services.sh

  test -L "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh \
    && rm "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh
  test -e "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh.bak \
    && mv "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh.bak "${BATS_TEST_DIRNAME}"/../bin/site-init-nginx-service.sh

  test -L "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh \
    && rm "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh
  test -e "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh.bak \
    && mv "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh.bak "${BATS_TEST_DIRNAME}"/../bin/site-init-service-object.sh

  rm -rf /etc/chillbox/sites
  rm -f $BATS_RUN_TMPDIR/aws
}

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

