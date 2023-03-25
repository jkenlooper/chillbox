#!/usr/bin/env python

import os
from pprint import pprint
import logging

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

from invoke import Collection, Program, Argument
from invoke.config import Config, merge_dicts

from chillbox._version import __version__
from chillbox import tasks
from chillbox.errors import ChillboxInvalidConfigError
from chillbox.utils import logger

# The default path to the chillbox configuration file should be at the top level
# of a project directory. The chillbox command would normally be executed at the
# top level of the project directory and the paths to other files would be
# relative to the configuration file.
chillbox_config_toml = "chillbox.toml"


class ChillboxProgram(Program):
    def run(self):
        run = super().run()
        return run

    def core_args(self):
        core_args = super().core_args()
        extra_args = [
            Argument(
                names=("chillbox-config", "c"),
                default=chillbox_config_toml,
                help="Chillbox configuration file in TOML format",
            ),
            Argument(names=("verbose", "v"), help="Verbose output", kind=bool),
        ]
        return core_args + extra_args

    def parse_cleanup(self):
        """
        Using parse_cleanup to act on some of the extra args that were passed
        in. This is one way to update the config object that is accessed by the
        run tasks.
        """
        parse_cleanup = super().parse_cleanup()

        if self.args.debug.value:
            logger.setLevel(logging.DEBUG)
        elif self.args.verbose.value:
            logger.setLevel(logging.INFO)

        # Need to copy over the arg to the config so it is available to the run
        # tasks.
        self.config["chillbox-config"] = self.args["chillbox-config"].value


class ChillboxConfig(Config):
    prefix = "chillbox"
    env_prefix = "CHILLBOX"

    @staticmethod
    def global_defaults():
        their_defaults = Config.global_defaults()
        my_defaults = {
            # TODO: Setting chillbox-config here is probably not necessary?
            "chillbox-config": chillbox_config_toml,
        }
        return merge_dicts(their_defaults, my_defaults)


program = ChillboxProgram(
    namespace=Collection.from_module(tasks),
    version=__version__,
    config_class=ChillboxConfig,
)


def main():
    program.run()


if __name__ == "__main__":
    main()
