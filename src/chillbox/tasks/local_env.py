import tempfile
import json
from pathlib import Path

from invoke import task

from chillbox.tasks.local_archive import init
from chillbox.state import ChillboxState
from chillbox.utils import (
    logger,
    remove_temp_files,
)


@task(pre=[init])
def output_env(c, sensitive=False):
    """
    Output environment variables and secrets to a temporary file.

    The format of the output is VARIABLE_NAME='value' per line. Only the secrets
    that the current owner has will be included if the --sensitive flag is
    used.

    Example use case:
        set -a; . '$(chillbox output-env)'; set +a
        ./run-some-other-script.sh

    Don't need to use 'export' in front of these if the 'set -a' is used. This
    also makes it more versatile since the output could be sent to a temporary
    file. That temp file could be used as an env file for docker.
    """

    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    temp_output_env_file = state.output_env_temp

    # Always delete any older ones first
    remove_temp_files(paths=[temp_output_env_file])

    temp_output_env = Path(tempfile.mkstemp(suffix=".chillbox.env")[1])
    state.output_env_temp = str(temp_output_env.resolve())
    logger.debug(f"{temp_output_env=}")

    # CHILLBOX_ARCHIVE_DIRECTORY="{c.archive_directory_path}"

    export_env_vars = {
        "CHILLBOX_INSTANCE": c.chillbox_config["instance"],
        # The chillbox archive directory should probably *not* be accessed by
        # outside scripts. Including it for now in case it is useful.
        "CHILLBOX_ARCHIVE_DIRECTORY": archive_directory.resolve(),
    }

    export_env_vars.update(c.env)

    if sensitive:
        export_env_vars.update(c.secrets)

    env_var_list = list(map(lambda x: f"{x[0]}='{x[1]}'", export_env_vars.items()))
    env_var_list.sort()
    temp_output_env.write_text("\n".join(env_var_list))

    # Only the file path is sent to stdout.
    print(temp_output_env.resolve())


@task(pre=[init])
def output_env_clean(c):
    """
    Remove the temporary output env file if it exists.

    The temporary output environment file may have secrets in plaintext.
    Removing this file when it is no longer needed is a good practice.
    """

    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    temp_output_env_file = state.output_env_temp

    remove_temp_files(paths=[temp_output_env_file])

    if state.output_env_temp:
        state.output_env_temp = None
