#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"

export CHILLBOX_BATS_IMAGE="${CHILLBOX_BATS_IMAGE:-chillbox-bats:latest}"

"$project_dir/tests/_docker_build_chillbox_bats.sh"

echo "Running shellcheck on all scripts."
docker run -it --rm \
  --mount "type=bind,src=${project_dir}/build,dst=/code/build,readonly=true" \
  --mount "type=bind,src=${project_dir}/chillbox.sh,dst=/code/chillbox.sh,readonly=true" \
  --mount "type=bind,src=${project_dir}/src,dst=/code/src,readonly=true" \
  --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
  --entrypoint="sh" \
  "$CHILLBOX_BATS_IMAGE" -c "find . ! -path './tests/*' \( -name '*.sh' -o -name '*.sh.tftpl' \) -exec shellcheck -f quiet {} +" \
  || \
    (docker run -it --rm \
      --mount "type=bind,src=${project_dir}/build,dst=/code/build,readonly=true" \
      --mount "type=bind,src=${project_dir}/chillbox.sh,dst=/code/chillbox.sh,readonly=true" \
      --mount "type=bind,src=${project_dir}/src,dst=/code/src,readonly=true" \
      --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
      --entrypoint="sh" \
      "$CHILLBOX_BATS_IMAGE" -c "find . ! -path './tests/*' \( -name '*.sh' -o -name '*.sh.tftpl' \) -exec shellcheck {} +" && exit 1)

echo "Passed shellcheck."
