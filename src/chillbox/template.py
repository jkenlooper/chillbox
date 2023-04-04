from pathlib import Path

from jinja2 import (
    Environment,
    PrefixLoader,
    ChoiceLoader,
    PackageLoader,
    FileSystemLoader,
    select_autoescape,
)
from jinja2.exceptions import TemplateNotFound

from chillbox.utils import logger
from chillbox.errors import (
    ChillboxTemplateError,
    ChillboxMissingFileError,
    ChillboxServerUserDataError,
)


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


class Renderer:
    """"""

    def raise_for_missing_template(self, missing_template):
        available_templates = "\n    - ".join(self.loader.list_templates())
        err_msg = "\n".join(
            [
                f"ERROR: The template ({missing_template}) is not an available template in the list: \n    - {available_templates}",
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

        fs_templates = map(
            lambda x: get_file_system_loader(x["src"], self.working_directory),
            filter(lambda x: not x.get("prefix"), template_list),
        )
        template_loaders = [PrefixLoader(prefix_loader)]
        template_loaders.extend(fs_templates)
        template_loaders.append(chillbox_data_loader)

        self.loader = ChoiceLoader(template_loaders)
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
