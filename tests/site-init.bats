#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}"/bats-logging-level.sh

setup_file() {
  test "${LOGGING_LEVEL}" -le $WARNING && echo -e "# \n# ${BATS_TEST_FILENAME}" >&3

  export slugname="site1"

  mkdir -p /usr/local/src

  tmp_dir=$(mktemp -d)
  export sites_artifact=$tmp_dir/sites.tar.gz

  cd "${BATS_TEST_DIRNAME}"/fixtures
  tar -c -z -f $sites_artifact sites

  export S3_ARTIFACT_ENDPOINT_URL="TODO"
  export ARTIFACT_BUCKET_NAME="TODO"
  export SITES_ARTIFACT="TODO"
  export CHILLBOX_SERVER_PORT="TODO"

  "${BATS_TEST_DIRNAME}"/../bin/create-env_names-file.sh

}

teardown_file() {
  rm -f /etc/chillbox/env_names
  test -d "$tmp_dir" && rm -rf $tmp_dir
  rm -rf /usr/local/src/site1
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

  mock_crontab="$(mock_create)"
  ln -s "${mock_crontab}" $BATS_RUN_TMPDIR/crontab

  PATH="$BATS_RUN_TMPDIR:$PATH"

  mkdir -p /usr/local/src/site1
  cp -Rf "${BATS_TEST_DIRNAME}"/fixtures/site1/nginx /usr/local/src/site1/
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

  test -L $BATS_RUN_TMPDIR/aws \
    && rm -f $BATS_RUN_TMPDIR/aws

  test -L $BATS_RUN_TMPDIR/crontab \
    && rm -f $BATS_RUN_TMPDIR/crontab

  rm -rf /etc/chillbox/sites
  rm -rf /usr/local/src/site1
  rm -rf /srv/site1/root
  rm -rf /srv/chillbox/site1/version.txt
  rm -rf /var/log/nginx/site1
  rm -rf /etc/chillbox/templates/site1.nginx.conf.template
}

main() {
  "${BATS_TEST_DIRNAME}"/../bin/site-init.sh $@
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

@test "pass when it cycles over sites from sites artifact file" {
  echo "# sites_artifact $sites_artifact" >&3
  run main "${sites_artifact}"
  assert_success

  test "$(mock_get_call_num "${mock_aws}")" -eq 1
  test "$(mock_get_call_num "${mock_crontab}")" -eq 1

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates the file /etc/chillbox/sites/site1.site.json" >&3
  test -f /etc/chillbox/sites/site1.site.json

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates the directory /usr/local/src/site1" >&3
  test -d /usr/local/src/site1

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates the directory /srv/site1/root" >&3
  test -d /srv/site1/root

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates the directory /var/log/nginx/site1" >&3
  test -d /var/log/nginx/site1

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates the file /etc/chillbox/templates/site1.nginx.conf.template" >&3
  test -f /etc/chillbox/templates/site1.nginx.conf.template

  test "${LOGGING_LEVEL}" -le $INFO && echo "# Creates the file /srv/chillbox/site1/version.txt" >&3
  test -f /srv/chillbox/site1/version.txt
}
