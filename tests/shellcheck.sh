#!/usr/bin/env sh

set -o errexit

tests_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "$tests_dir")"

export CHILLBOX_BATS_IMAGE="${CHILLBOX_BATS_IMAGE:-chillbox-bats:latest}"

"$tests_dir/_docker_build_chillbox_bats.sh"

echo "Running shellcheck on all scripts."
docker run -it --rm \
  --mount "type=bind,src=${project_dir}/local-bin,dst=/code/local-bin,readonly=true" \
  --mount "type=bind,src=${project_dir}/terra.sh,dst=/code/terra.sh,readonly=true" \
  --mount "type=bind,src=${project_dir}/src/terraform/bin,dst=/code/terraform-bin,readonly=true" \
  --mount "type=bind,src=${project_dir}/src/terraform/010-infra,dst=/code/terraform-010-infra,readonly=true" \
  --mount "type=bind,src=${project_dir}/src/terraform/020-chillbox,dst=/code/terraform-020-chillbox,readonly=true" \
  --mount "type=bind,src=${project_dir}/src/chillbox/bin,dst=/code/bin,readonly=true" \
  --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
  --entrypoint="sh" \
  "$CHILLBOX_BATS_IMAGE" -c "find . ! -path './tests/*' \( -name '*.sh' -o -name '*.sh.tftpl' \) -exec shellcheck -f quiet {} +" \
  || \
    (docker run -it --rm \
      --mount "type=bind,src=${project_dir}/local-bin,dst=/code/local-bin,readonly=true" \
      --mount "type=bind,src=${project_dir}/terra.sh,dst=/code/terra.sh,readonly=true" \
      --mount "type=bind,src=${project_dir}/src/terraform/bin,dst=/code/terraform-bin,readonly=true" \
      --mount "type=bind,src=${project_dir}/src/terraform/010-infra,dst=/code/terraform-010-infra,readonly=true" \
      --mount "type=bind,src=${project_dir}/src/terraform/020-chillbox,dst=/code/terraform-020-chillbox,readonly=true" \
      --mount "type=bind,src=${project_dir}/src/chillbox/bin,dst=/code/bin,readonly=true" \
      --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
      --entrypoint="sh" \
      "$CHILLBOX_BATS_IMAGE" -c "find . ! -path './tests/*' \( -name '*.sh' -o -name '*.sh.tftpl' \) -exec shellcheck {} +" && exit 1)

echo "Passed shellcheck."
