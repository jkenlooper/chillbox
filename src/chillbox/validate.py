from pathlib import Path
from pprint import pformat

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

from chillbox.errors import ChillboxInvalidConfigError, ChillboxMissingFileError
from chillbox.local_checks import check_required_commands
from chillbox.utils import logger

required_keys = set(["instance", "gpg-key", "archive-directory"])

# TODO: Reference the docs/configuration-file.md file that is hosted at a URL instead?
chillbox_config_more_info = "Please see documentation at docs/configuration-file.md"


def validate_and_load_chillbox_config(chillbox_config_file):
    "Load the parsed TOML data to the context so it can be used by other tasks."
    check_required_commands()

    logger.debug(f"Using chillbox config file: {chillbox_config_file}")

    if not Path(chillbox_config_file).exists():
        abs_path_chillbox_config = Path(chillbox_config_file).resolve()
        raise ChillboxMissingFileError(
            f"ERROR: No chillbox configuration file at: {abs_path_chillbox_config}\n    {chillbox_config_more_info}"
        )

    with open(chillbox_config_file, "rb") as f:
        try:
            data = tomllib.load(f)
        except tomllib.TOMLDecodeError as err:
            raise ChillboxInvalidConfigError(
                f"INVALID: Failed to parse the {f.name} file.\n  {err}"
            )
        logger.debug(pformat(data))

    top_level_keys = set(data.keys())
    if not required_keys.issubset(top_level_keys):
        missing_keys = required_keys.copy()
        missing_keys.difference_update(top_level_keys)
        lines = "\n  ".join(sorted(missing_keys))
        raise ChillboxInvalidConfigError(
            f"INVALID: Missing required keys in the {f.name} file.\nThe following keys are required:\n  {lines}\n    {chillbox_config_more_info}"
        )

    for server in data.get("server", []):
        missing_keys = ["name"]
        lines = "\n  ".join(sorted(missing_keys))
        if not server.get("name"):
            raise ChillboxInvalidConfigError(
                f"INVALID: Missing required keys in the {f.name} file.\nThe following keys are required for items in server:\n  {lines}\n  The server object with error is:\n    {pformat(server)}"
            )
        user_data = server.get("user-data")
        if user_data and not user_data.get("template"):
            raise ChillboxInvalidConfigError(
                f"INVALID: Missing required keys in the {f.name} file.\nThe following keys are required for items in server.user-data:\n  template\n  The server object with error is:\n    {pformat(server)}"
            )

    logger.info(f"Valid configuration file: {f.name}")

    # c.chillbox_config = data
    return data
