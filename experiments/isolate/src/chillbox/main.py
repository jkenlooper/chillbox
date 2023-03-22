#!/usr/bin/env python

import os
from pprint import pprint

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

from invoke import Collection, Program, Argument

from chillbox._version import __version__
from chillbox import tasks
from chillbox.errors import ChillboxInvalidConfigError

class ChillboxProgram(Program):

    def run(self):
        print('run')
        run = super().run()
        return run


    def core_args(self):
        print('core_args')
        core_args = super().core_args()
        extra_args = [
            Argument(names=('foo', 'u'), help="Foo the bars"),
            # ...
        ]
        return core_args + extra_args

    def parse_cleanup(self):
        print('parse_cleanup')
        parse_cleanup = super().parse_cleanup()

program = ChillboxProgram(namespace=Collection.from_module(tasks), version=__version__)


def main():
    program.run()


if __name__ == "__main__":
    main()
