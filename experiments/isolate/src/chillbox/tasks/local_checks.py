from shutil import which

from invoke import task

from chillbox.errors import ChillboxDependencyError

required_commands = set(
    [
        "openssl",
        "python",
        "gpg",
    ]
)

optional_commands = set(
    [
        "terraform",
        "whoami",
    ]
)


def has_command(cmd):
    print(f"Checking for command '{cmd}'.")
    return False if which(cmd) is None else True


def get_missing_commands_from_set(cmd_set):
    cmds = sorted(cmd_set)
    results = list(map(
        lambda y: y[0], filter(lambda x: not x[1], zip(cmds, map(has_command, cmds)))
    ))
    return results


@task
def check_required_commands(c):
    results = get_missing_commands_from_set(required_commands)

    if results:
        lines = "\n  ".join(results)
        raise ChillboxDependencyError(
            f"INVALID: Missing required commands.\nThe following commands were not found:\n  {lines}"
        )


@task
def check_optional_commands(c):
    results = get_missing_commands_from_set(optional_commands)

    lines = "\n  ".join(results)
    raise ChillboxDependencyError(
        f"INVALID: Missing optional commands.\nThe following commands were not found:\n  {lines}"
    )
