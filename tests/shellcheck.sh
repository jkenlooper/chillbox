#!/usr/bin/env sh

set -o errexit

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"
# Only checking POSIX shell scripts that use a shebang with the 'env' command.
# Support shell scripts that pass args to shebang lines.
shebang_line_to_match="^#!/usr/bin/env .*\bsh"

export CHILLBOX_BATS_IMAGE="${CHILLBOX_BATS_IMAGE:-chillbox-bats:latest}"

"$project_dir/tests/_docker_build_chillbox_bats.sh"

echo "Running shellcheck on all scripts."
docker run -it --rm \
  --mount "type=bind,src=${project_dir}/build,dst=/code/build,readonly=true" \
  --mount "type=bind,src=${project_dir}/chillbox.sh,dst=/code/chillbox.sh,readonly=true" \
  --mount "type=bind,src=${project_dir}/ansible.sh,dst=/code/ansible.sh,readonly=true" \
  --mount "type=bind,src=${project_dir}/src,dst=/code/src,readonly=true" \
  --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
  --entrypoint="sh" \
  "$CHILLBOX_BATS_IMAGE" -c "find . -type f -not \( -name '*Dockerfile' -o -name 'README*' \) | xargs -I {} grep -l '$shebang_line_to_match' {} | xargs -I {} shellcheck -f quiet {}" \
  || \
    (docker run -it --rm \
      --mount "type=bind,src=${project_dir}/build,dst=/code/build,readonly=true" \
      --mount "type=bind,src=${project_dir}/chillbox.sh,dst=/code/chillbox.sh,readonly=true" \
      --mount "type=bind,src=${project_dir}/ansible.sh,dst=/code/ansible.sh,readonly=true" \
      --mount "type=bind,src=${project_dir}/src,dst=/code/src,readonly=true" \
      --mount "type=bind,src=${project_dir}/tests,dst=/code/tests,readonly=true" \
      --entrypoint="sh" \
      "$CHILLBOX_BATS_IMAGE" -c "find . -type f -not \( -name '*Dockerfile' -o -name 'README*' \) | xargs -I {} grep -l '$shebang_line_to_match' {} | xargs -I {} shellcheck {}" && exit 1)

echo "Passed shellcheck."
