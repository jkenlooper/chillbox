from pathlib import Path

from invoke import task
from jinja2 import Environment, PrefixLoader, ChoiceLoader, PackageLoader, FileSystemLoader, select_autoescape
from jinja2.exceptions import TemplateNotFound

from chillbox.validate import validate_and_load_chillbox_config
from chillbox.utils import logger
from chillbox.errors import ChillboxMissingFileError


def generate_user_data_script(c):
    ""
    #import importlib.resources as pkg_resources
    #with open(pkg_resources.path(chillbox.data, "commands-info.toml"), "rb") as f:

    server_list = c.chillbox_config.get("server", [])
    logger.debug(server_list)
    archive_directory = Path(c.chillbox_config["archive-directory"])
    archive_templates = archive_directory.joinpath("templates")
    archive_templates.mkdir(parents=True, exist_ok=True)

    chillbox_data_loader = PackageLoader("chillbox.data")
    loader = ChoiceLoader([
        PrefixLoader({
            "chillbox": PackageLoader("chillbox.data"),
            "archive": FileSystemLoader(archive_templates.resolve()),
        }),
        FileSystemLoader(archive_templates.resolve()),
        chillbox_data_loader
    ])
    env = Environment(loader=loader, autoescape=select_autoescape())
    logger.debug(loader.list_templates())

    def raise_for_missing_template(missing_template):
        available_templates = "\n    - ".join(loader.list_templates())
        err_msg = "\n".join([
            f"ERROR: The template ({missing_template}) is not an available template in the list: \n    - {available_templates}",
            f"  Templates with prefix 'archive/' are loaded from:\n    {archive_templates.resolve()}",
            f"  Templates with prefix 'chillbox/' are loaded from:\n    {chillbox_data_loader._template_root}",
            "  Templates with no prefix will load archive/ templates before chillbox/ templates."
        ])
        raise ChillboxMissingFileError(err_msg)

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
        server_user_data_context.update(server_user_data.get("context", {}))

        try:
            template = env.get_template(server_user_data_template)
        except TemplateNotFound as err:
            logger.debug(err)
            raise_for_missing_template(str(err))
        try:
            user_data_script = template.render(server_user_data_context)
        except TemplateNotFound as err:
            logger.debug(err)
            raise_for_missing_template(str(err))
        logger.debug(user_data_script)

@task
def server_init(c):
    "Initialize files that will be needed for the chillbox servers."

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    generate_user_data_script(c)
