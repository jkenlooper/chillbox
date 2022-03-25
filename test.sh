#!/usr/bin/env sh

# No context for the docker build is needed.
export DOCKER_BUILDKIT=1
cat tests/Dockerfile | docker build -t chillbox-bats:latest -

# Default to run all tests in tests directory.
TEST=${1:-"tests"}

debug=${DEBUG:-"n"}
if [ "$debug" = "y" ]; then
  docker run -it --rm \
    --mount "type=bind,src=$(pwd)/bin,dst=/code/bin" \
    --mount "type=bind,src=$(pwd)/tests,dst=/code/tests" \
    --entrypoint="sh" \
    chillbox-bats:latest

else
  docker run -it --rm \
    --mount "type=bind,src=$(pwd)/bin,dst=/code/bin" \
    --mount "type=bind,src=$(pwd)/tests,dst=/code/tests" \
    chillbox-bats:latest $TEST

fi
