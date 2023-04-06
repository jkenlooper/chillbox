from pathlib import Path
from pprint import pformat
import getpass
from datetime import date

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

from jinja2.exceptions import TemplateNotFound

from chillbox.errors import ChillboxInvalidConfigError, ChillboxMissingFileError, ChillboxTemplateError
from chillbox.local_checks import check_required_commands
from chillbox.utils import logger, get_file_system_loader

required_keys = set(["instance", "gpg-key", "archive-directory"])
required_keys_path = set(["id", "src", "dest"])

# TODO: Reference the docs/configuration-file.md file that is hosted at a URL instead?
chillbox_config_more_info = "Please see documentation at docs/configuration-file.md"

def src_path_is_template(src, template_list, working_directory):
    "Return True if src path is a template"

    def is_prefix_path(src):
        prefix_split = src.split(sep=":", maxsplit=1)
        if len(prefix_split) > 1:
            if prefix_split[0].find("/") == -1:
                return True
    src_path = Path(working_directory).joinpath(src)
    if src.startswith(("/", "./")):
        return False
    if src_path.exists() and src_path.is_dir():
        return False
    if is_prefix_path(src):
        return True

    for template in template_list:
        if template.get("prefix"):
            # Skip if prefix since those have already been checked.
            continue
        template_src = template.get("src")
        if not template_src:
            # The template object is invalid, but not concerned about that here.
            continue
        try:
            fs_loader = get_file_system_loader(template_src, working_directory)
        except ChillboxTemplateError as err:
            # Ignore this error here as this is only concerning itself with the
            # path src value.
            continue
        try:
            fs_loader.get_source(environment=None, template=src)
        except TemplateNotFound:
            # Ignore so other templates can be checked.
            continue

        if src_path.exists():
            logger.warning(f"The src path exists at: {src_path.resolve()} and is a file in the template list. This path can't be used as a template because it is ambiguous.")
            return False

        # fs_loader was able to load the template file so it must be an actual
        # template.
        return True

    return False


def validate_and_load_chillbox_config(chillbox_config_file):
    "Load the parsed TOML data to the context so it can be used by other tasks."
    check_required_commands()

    working_directory = Path(chillbox_config_file).resolve().parent
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
        lines = "\n  - ".join(sorted(missing_keys))
        raise ChillboxInvalidConfigError(
            f"INVALID: Missing required keys in the {f.name} file.\nThe following keys are required:\n  - {lines}\n    {chillbox_config_more_info}"
        )

    ## template
    template_prefixes = list(map(lambda x: x["prefix"], filter(lambda x: x.get("prefix"), data.get("template", []))))
    if len(template_prefixes) != len(set(template_prefixes)):
        raise ChillboxInvalidConfigError(
            "INVALID: Duplicate template prefix found. The prefix used for each template must be unique."
        )

    ## path
    for path in data.get("path", []):
        path_keys = set(path.keys())
        if not required_keys_path.issubset(path_keys):
            logger.warning(f"The path object is invalid: {path}")
            missing_keys = required_keys_path.copy()
            missing_keys.difference_update(path_keys)
            lines = "\n  - ".join(sorted(missing_keys))
            raise ChillboxInvalidConfigError(
                f"INVALID: Missing required keys in the {f.name} file.\nThe following keys are required for path:\n  - {lines}\n    {chillbox_config_more_info}"
            )

        # Check if src is a template else check if src exists
        if path.get("render") and src_path_is_template(path["src"], data.get("template", []), working_directory):
            logger.debug(f"src path ({path['src']}) is a template file")
        else:
            src_path = working_directory.joinpath(path["src"]).resolve()
            logger.debug(src_path)
            logger.debug(working_directory)
            if not src_path.is_relative_to(working_directory):
                raise ChillboxInvalidConfigError(
                    f"INVALID: The path with id of '{path['id']}' has a src ({src_path}) that is outside the working directory: {working_directory.resolve()}"
                )
            if not src_path.exists():
                raise ChillboxInvalidConfigError(f"INVALID: The path with id of '{path['id']}' has a src ({src_path}) that does not exist.")

        if path.get("context") and not path.get("render"):
            logger.warning(f"The path with id of '{path['id']}' has 'context' value defined, but will not be used since 'render' value is not true.")

        if not Path(path["dest"]).is_absolute():
            raise ChillboxInvalidConfigError(
                f"INVALID: The dest value on path with id of '{path['id']}' should be an absolute path: {path['dest']}"
            )
    path_ids = list(map(lambda x: x["id"], data.get("path", [])))
    if len(path_ids) != len(set(path_ids)):
        raise ChillboxInvalidConfigError(
            "INVALID: Duplicate path id found. The id used for each path must be unique."
        )

    ## server
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
    server_names = list(map(lambda x: x["name"], data.get("server", [])))
    if len(server_names) != len(set(server_names)):
        raise ChillboxInvalidConfigError(
            "INVALID: Duplicate server name found. The name used for each server must be unique."
        )

    today = date.today()
    owner = getpass.getuser()
    for secret in data.get("secret", []):
        if secret.get("owner") != owner:
            continue
        expires_date = secret.get("expires")
        if today > expires_date:
            logger.warning(
                f"The secret '{secret.get('id')}' exists, but it has expired."
            )

    logger.info(f"Valid configuration file: {f.name}")

    # c.chillbox_config = data
    return data
