from pathlib import Path
import hashlib
from tempfile import mkstemp
import bz2
from shutil import copyfileobj
from copy import deepcopy

from invoke import task
from jinja2 import (
    Environment,
    PrefixLoader,
    ChoiceLoader,
    PackageLoader,
    FileSystemLoader,
    select_autoescape,
)
from jinja2.exceptions import TemplateNotFound
import httpx

from chillbox.tasks.local_archive import init
from chillbox.validate import validate_and_load_chillbox_config
from chillbox.utils import (
    logger,
    encrypt_file,
    shred_file,
)
from chillbox.errors import (
    ChillboxServerUserDataError,
    ChillboxDependencyError,
)
from chillbox.local_checks import check_optional_commands


def generate_password_hash(c, user):
    ""
    print(f"No password_hash set for user '{user}'. Enter new password for this user.")
    result = c.run(
        "openssl passwd -6", hide=True
    )
    return result.stdout.strip()

def user_password_hash_init(c):
    ""
    current_user = c.state["current_user"]

    current_user_data = list(filter(lambda x: x["name"] == current_user, c.chillbox_config.get("user", [])))[0]
    state_current_user_data = c.state.get("current_user_data", {})
    current_user_data.update(state_current_user_data)
    if not current_user_data.get("password_hash"):
        password_hash = generate_password_hash(c, current_user)
        state_current_user_data["password_hash"] = password_hash
        c.state["current_user_data"] = state_current_user_data


def generate_user_data_script(c):
    """"""
    server_list = c.chillbox_config.get("server", [])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    current_user = c.state["current_user"]

    for server in server_list:
        server_owner = server.get("owner")
        logger.debug(f"Server owner {server_owner}")
        if not server_owner or server_owner != current_user:
            continue
        server_user_data = server.get("user-data")
        if not server_user_data:
            continue
        server_user_data_template = server_user_data.get("template")
        if not server_user_data_template:
            continue

        user_data_script_file = archive_directory.joinpath(
            "server", server["name"], "user-data"
        )
        if user_data_script_file.exists():
            logger.info(f"Skipping replacement of existing user-data file: {user_data_script_file}")
            continue

        # TODO public ssh key should be of the current_user
        result = list(filter(lambda x: x["name"] == current_user, c.chillbox_config["user"]))
        if not result:
            logger.warning(f"No user name matches with server owner ({server_owner})")
            continue
        current_user_data = result[0]

        # TODO Check if the user has a public ssh key set? Generate new one if
        # they don't and save public ssh key to statefile. The private key
        # should be encrypted with the gpg key (Already managed by chillbox?).



        # TODO Check if the user has a password hash set? Generate new one if
        # they don't and store it in statefile. Password hash is not sensitive.

        server_user_data_context = {
            "chillbox_env": deepcopy(dict(c.env)),
            "chillbox_user": current_user_data,
            "chillbox_server": server,
        }

        # The server user-data context should not get c.secrets. The user-data
        # is not encrypted.
        server_user_data_context.update(server_user_data.get("context", {}))

        user_data_text = c.renderer.render(
            server_user_data_template, server_user_data_context
        )

        user_data_script_file.parent.mkdir(parents=True, exist_ok=True)
        user_data_file_size_limit = server_user_data.get("file-size-limit")
        if (
            user_data_file_size_limit
            and len(user_data_text) >= user_data_file_size_limit
        ):
            logger.info(user_data_text)
            raise ChillboxServerUserDataError(
                f"ERROR: The rendered server ({server['name']}) user-data is over the file size limit. Limit is {user_data_file_size_limit} and user-data bytes is {len(user_data_text)}."
            )

        user_data_script_file.write_text(user_data_text)


def output_current_user_public_ssh_key(c):
    server_list = c.chillbox_config.get("server", [])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    current_user = c.state["current_user"]

    for server in server_list:
        server_owner = server.get("owner")
        if not server_owner or server_owner != current_user:
            continue

        public_ssh_key_file = archive_directory.joinpath(
            "server", server["name"], "public_ssh_key"
        )
        if public_ssh_key_file.exists():
            public_ssh_key_file.unlink()
        public_ssh_key_file.parent.mkdir(parents=True, exist_ok=True)
        public_ssh_key_file.write_text("\n".join(c.state["current_user_data"]["public_ssh_key"]))


@task(pre=[init])
def server_init(c):
    "Initialize files that will be needed for the chillbox servers."

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    user_password_hash_init(c)
    generate_user_data_script(c)
    output_current_user_public_ssh_key(c)
