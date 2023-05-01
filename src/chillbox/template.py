from pathlib import Path

from jinja2 import (
    Environment,
    PrefixLoader,
    PackageLoader,
    FileSystemLoader,
    select_autoescape,
)
from jinja2.exceptions import TemplateNotFound

from chillbox.utils import logger, get_file_system_loader
from chillbox.errors import (
    ChillboxTemplateError,
    ChillboxMissingFileError,
    ChillboxServerUserDataError,
)


class Renderer:
    """
    Provides a template renderer that loads templates from multiple locations on the file system.

    Prefix loaders use a ':' delimiter to separate the prefix from the path.

    - 'chillbox-scripts:' contains common scripts that chillbox uses.
    - 'chillbox:' has other general templates like user-data scripts.
    - Other templates are defined by the chillbox configuration that was loaded.
    """

    def raise_for_missing_template(self, err):
        available_templates = "\n    - ".join(self.loader.list_templates())
        err_msg = "\n".join(
            [
                f"ERROR: {err}\n  Available template in the list: \n    - {available_templates}",
            ]
        )
        raise ChillboxMissingFileError(err_msg)

    def __init__(self, template_list, working_directory):
        """"""
        self.working_directory = Path(working_directory)

        chillbox_data_loader = PackageLoader("chillbox.data")
        prefix_loader = {
            "chillbox-scripts": PackageLoader("chillbox.data", package_path="scripts"),
            "chillbox": PackageLoader("chillbox.data"),
        }
        prefix_templates = dict(
            map(
                lambda x: (
                    x["prefix"],
                    get_file_system_loader(x["src"], self.working_directory),
                ),
                filter(lambda x: x.get("prefix"), template_list),
            )
        )
        prefix_loader.update(prefix_templates)
        logger.debug(prefix_loader)

        self.loader = PrefixLoader(prefix_loader, delimiter=":")
        self.env = Environment(loader=self.loader, autoescape=select_autoescape())

    def render(self, file, context):
        """"""
        try:
            template = self.env.get_template(file)
        except TemplateNotFound as err:
            logger.debug(err)
            self.raise_for_missing_template(str(err))
        try:
            output_text = template.render(context)
        except TemplateNotFound as err:
            logger.debug(err)
            self.raise_for_missing_template(str(err))
        logger.debug(output_text)
        return output_text
