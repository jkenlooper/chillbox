#!/usr/bin/env sh

set -o errexit

# The tests need to be executed from the top level of the project.
tests_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "$tests_dir")"
cd "${project_dir}"

# Default to run all tests (any files with '.bats' extension) in tests directory.
TEST="tests/"

# Need to verify that if an argument is passed in it is an actual path to a bats file.
if [ -n "$1" ]; then
  bats_file_without_extension=$(basename "$1" .bats)
  test -e "${tests_dir}/$bats_file_without_extension.bats" || (echo "ERROR $0: The path '${tests_dir}/$bats_file_without_extension.bats' does not exist." && exit 1)
  TEST="tests/$bats_file_without_extension.bats"
fi

# No context for the docker build is needed.
docker image rm chillbox-bats:latest || printf ""
export DOCKER_BUILDKIT=1
docker build -t chillbox-bats:latest - < "${tests_dir}/Dockerfile"

# When developing and writing tests it is useful to execute and debug tests directly.
debug=${DEBUG:-"n"}
if [ "$debug" = "y" ]; then
  docker run -it --rm \
    --mount "type=bind,src=${project_dir}/bin,dst=/code/bin,readonly=true" \
    --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
    --entrypoint="sh" \
    chillbox-bats:latest

# Default to run all tests or the test that was passed in.
else

  # Run shellcheck on all scripts and fail if there are issues
  docker run -it --rm \
    --mount "type=bind,src=${project_dir}/local-bin,dst=/code/local-bin,readonly=true" \
    --mount "type=bind,src=${project_dir}/terra.sh,dst=/code/terra.sh,readonly=true" \
    --mount "type=bind,src=${project_dir}/terraform-bin,dst=/code/terraform-bin,readonly=true" \
    --mount "type=bind,src=${project_dir}/terraform-010-infra,dst=/code/terraform-010-infra,readonly=true" \
    --mount "type=bind,src=${project_dir}/terraform-020-chillbox,dst=/code/terraform-020-chillbox,readonly=true" \
    --mount "type=bind,src=${project_dir}/bin,dst=/code/bin,readonly=true" \
    --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
    --entrypoint="sh" \
    chillbox-bats:latest -c "find . ! -path './tests/*' \( -name '*.sh' -o -name '*.sh.tftpl' \) -exec shellcheck -f quiet {} +" \
    || \
      (docker run -it --rm \
        --mount "type=bind,src=${project_dir}/local-bin,dst=/code/local-bin,readonly=true" \
        --mount "type=bind,src=${project_dir}/terra.sh,dst=/code/terra.sh,readonly=true" \
        --mount "type=bind,src=${project_dir}/terraform-bin,dst=/code/terraform-bin,readonly=true" \
        --mount "type=bind,src=${project_dir}/terraform-010-infra,dst=/code/terraform-010-infra,readonly=true" \
        --mount "type=bind,src=${project_dir}/terraform-020-chillbox,dst=/code/terraform-020-chillbox,readonly=true" \
        --mount "type=bind,src=${project_dir}/bin,dst=/code/bin,readonly=true" \
        --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
        --entrypoint="sh" \
        chillbox-bats:latest -c "find . ! -path './tests/*' \( -name '*.sh' -o -name '*.sh.tftpl' \) -exec shellcheck {} +" && exit 1)

  docker run -it --rm \
    --mount "type=bind,src=${project_dir}/bin,dst=/code/bin,readonly=true" \
    --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
    chillbox-bats:latest "$TEST"

fi

printf '\n%s\n' "Run integration test with a deployment with Terraform? [y/n]"
read -r CONFIRM
if [ "${CONFIRM}" = "y" ]; then
  WORKSPACE="test" ./terra.sh

  # TODO Automated checking of deployed test site is not implemented.
  exit

  app_port=9081
  echo "
  Sites running on http://chillbox.test:$app_port
  "
  for a in 0 1 2; do
    test $a -eq 0 || sleep 1
    echo "Checking if chillbox is up."
    curl --retry 3 --retry-connrefused --silent --show-error "http://chillbox.test:$app_port/healthcheck/" || continue
    break
  done
  tmp_sites_dir=$(mktemp -d)
  docker cp chillbox:/etc/chillbox/sites "$tmp_sites_dir/sites"
  cd "$tmp_sites_dir"
  sites=$(find sites -type f -name '*.site.json')
  for site_json in $sites; do
    echo ""
    slugname="$(basename "$site_json" .site.json)"
    server_name="$(jq -r '.server_name' "$site_json")"
    echo "$slugname"
    echo "http://chillbox.test:$app_port/$slugname/version.txt"
    printf " Version: "
    deployed_version="$(curl --retry 1 --retry-connrefused  --fail --show-error --no-progress-meter "http://chillbox.test:$app_port/$slugname/version.txt")"
    test -z "$deployed_version" && echo "NO VERSION FOUND" && continue
    curl --fail --show-error --no-progress-meter "http://chillbox.test:$app_port/$slugname/version.txt"
    echo "http://$slugname.test:$app_port"
    curl --fail --show-error --silent --head "http://$server_name:$app_port" || continue
  done
  cd -
  rm -rf "$tmp_sites_dir"

fi
