import os
import logging
import json
from pathlib import Path

from jinja2 import FileSystemLoader

from chillbox.errors import (
    ChillboxInvalidStateFileError,
    ChillboxTemplateError,
)

LOG_FORMAT = "%(levelname)s: %(name)s.%(module)s.%(funcName)s:\n  %(message)s"
logging.basicConfig(level=logging.WARNING, format=LOG_FORMAT)
# Allow invoke debugging mode if the env var is set for it.
logger = logging.getLogger(
    "chillbox" if not os.environ.get("INVOKE_DEBUG") else "invoke"
)


def get_state_file_data(archive_directory):
    state_file = archive_directory.joinpath("statefile.json")
    if state_file.exists():
        with open(state_file.resolve(), "r") as f:
            try:
                state_file_data = json.load(f)
            except json.decoder.JSONDecodeError as err:
                raise ChillboxInvalidStateFileError(
                    f"ERROR: Failed to parse json file ({f.name}).\n  {err}"
                )

    else:
        state_file_data = {}

    return state_file_data


def save_state_file_data(archive_directory, state_file_data):
    state_file = archive_directory.joinpath("statefile.json")
    with open(state_file.resolve(), "w") as f:
        json.dump(state_file_data, f)


def remove_temp_files(paths=[]):
    for f in paths:
        if f and Path(f).exists():
            # TODO: Overwrite data first before unlinking to more securely
            # delete sensitive information like secrets.
            Path(f).unlink()


def get_file_system_loader(src, working_directory):
    src_path = working_directory.joinpath(src).resolve()
    if not src_path.is_relative_to(working_directory):
        raise ChillboxTemplateError(
            f"ERROR: The template src path ({src_path}) is outside the working directory: {working_directory.resolve()}"
        )
    if not src_path.is_dir():
        raise ChillboxTemplateError(
            f"ERROR: The template src path is not a directory: {src_path.resolve()}"
        )
    return FileSystemLoader(src_path)

