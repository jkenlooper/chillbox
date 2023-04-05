import os
import logging
import json
from pathlib import Path
import subprocess

from jinja2 import FileSystemLoader

from chillbox.errors import (
    ChillboxInvalidStateFileError,
    ChillboxTemplateError,
    ChillboxExit,
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


def shred_file(file):
    """
    Overwrite data first before unlinking to more securely delete sensitive
    information like secrets. Uses the 'shred' command, but falls back on
    unlinking if that fails.
    """

    if not Path(file).exists():
        logger.warning(f"The file ({file}) does not exist. Nothing to shred.")
        return
    if Path(file).is_dir():
        raise ChillboxExit(f"ERROR: The path ({file}) is a directory. Shredding files in a directory is not supported.")

    try:
        result = subprocess.run(
            ["shred", "-fuz", str(file)], capture_output=True, check=True, text=True
        )
        logger.debug(result)
    except FileNotFoundError as err:
        logger.warning(f"Failed to properly shred {file} file.\n  {err}")
    except subprocess.CalledProcessError as err:
        logger.warning(f"Failed to properly shred {file} file.\n  {err}")
    finally:
        if Path(file).exists():
            logger.warning(f"Only performing an unlink of the {file} file.")
            Path(file).unlink()


def remove_temp_files(paths=[]):
    for f in paths:
        if f and Path(f).exists():
            shred_file(f)


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

