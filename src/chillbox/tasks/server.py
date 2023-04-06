from pathlib import Path

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

from chillbox.tasks.local_archive import init
from chillbox.validate import validate_and_load_chillbox_config
from chillbox.utils import logger
from chillbox.errors import ChillboxMissingFileError, ChillboxServerUserDataError


def generate_user_data_script(c):
    """"""
    server_list = c.chillbox_config.get("server", [])
    logger.debug(server_list)
    archive_directory = Path(c.chillbox_config["archive-directory"])

    for server in server_list:
        server_user_data = server.get("user-data")
        if not server_user_data:
            continue
        server_user_data_template = server_user_data.get("template")
        if not server_user_data_template:
            continue
        server_user_data_context = {
            "public_ssh_keys": ["public ssh key"],
            "hostname": "",
            "login_users": [],
            "no_home_users": [],
        }

        server_user_data_context.update(c.env)
        # The server user-data context should not get c.secrets. The user-data
        # is not encrypted.
        server_user_data_context.update(server_user_data.get("context", {}))

        user_data_text = c.renderer.render(server_user_data_template, server_user_data_context)

        user_data_script_file = archive_directory.joinpath(
            "server", server["name"], "user-data"
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


@task(pre=[init])
def server_init(c):
    "Initialize files that will be needed for the chillbox servers."

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    generate_user_data_script(c)
