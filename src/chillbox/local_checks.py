from shutil import which
import importlib.resources as pkg_resources

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

from chillbox.errors import ChillboxDependencyError
from chillbox.utils import logger, get_template
import chillbox.data


def has_command(cmd):
    logger.info(f"Checking for command '{cmd}'.")
    return False if which(cmd) is None else True


def get_missing_commands_from_set(cmd_set):
    cmds = sorted(cmd_set)
    results = list(
        map(
            lambda y: y[0],
            filter(lambda x: not x[1], zip(cmds, map(has_command, cmds))),
        )
    )
    return results


def check_required_commands():
    with open(pkg_resources.path(chillbox.data, "commands-info.toml"), "rb") as f:
        commands_info = tomllib.load(f)
    required_commands = set(
        map(lambda y: y[0], filter(lambda x: x[1]["required"], commands_info.items()))
    )
    results = get_missing_commands_from_set(required_commands)

    if results:
        with open(pkg_resources.path(chillbox.data, "commands-info.toml"), "rb") as f:
            commands_info = tomllib.load(f)
        template = get_template("commands-info.jinja")
        info = template.render(**locals())
        lines = "\n  ".join(results)
        raise ChillboxDependencyError(
            f"INVALID: Missing required commands.\nThe following commands were not found:\n  {lines}\n\nMore details about missing commands:\n---{info}"
        )


def check_optional_commands():
    with open(pkg_resources.path(chillbox.data, "commands-info.toml"), "rb") as f:
        commands_info = tomllib.load(f)
    optional_commands = set(
        map(
            lambda y: y[0],
            filter(lambda x: not x[1]["required"], commands_info.items()),
        )
    )
    results = get_missing_commands_from_set(optional_commands)

    if results:
        with open(pkg_resources.path(chillbox.data, "commands-info.toml"), "rb") as f:
            commands_info = tomllib.load(f)
        template = get_template("commands-info.jinja")
        info = template.render(**locals())
        lines = "\n  ".join(results)
        raise ChillboxDependencyError(
            f"Missing optional commands.\nThe following commands were not found:\n  {lines}\n\nMore details about missing commands:\n---{info}"
        )
