#!/usr/bin/env sh

set -o errexit

# The tests need to be executed from the top level of the project.
tests_dir="$(dirname $(realpath $0))"
project_dir="$(dirname $tests_dir)"
cd "${project_dir}"

# Need to verify that any arg passed in is an actual path.
if [ -n "$1" ]; then
  test -e "${tests_dir}"/"$1" || (echo "ERROR $0: The path '${tests_dir}/$1' does not exist." && exit 1)
fi

# No context for the docker build is needed.
export DOCKER_BUILDKIT=1
cat "${tests_dir}/Dockerfile" | docker build -t chillbox-bats:latest -

# Default to run all tests (any files with '.bats' extension) in tests directory.
TEST="tests/"${1:-""}

# When developing and writing tests it is useful to execute and debug tests directly.
debug=${DEBUG:-"n"}
if [ "$debug" = "y" ]; then
  docker run -it --rm \
    --mount "type=bind,src=${project_dir}/bin,dst=/code/bin" \
    --mount "type=bind,src=${project_dir}/tests,dst=/code/tests" \
    --entrypoint="sh" \
    chillbox-bats:latest

# Default to run all tests or the test that was passed in.
else
  docker run -it --rm \
    --mount "type=bind,src=${project_dir}/bin,dst=/code/bin" \
    --mount "type=bind,src=${project_dir}/tests,dst=/code/tests" \
    chillbox-bats:latest $TEST

fi
