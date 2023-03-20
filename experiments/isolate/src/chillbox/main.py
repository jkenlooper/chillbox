#!/usr/bin/env python

import os
from pprint import pprint
from functools import reduce

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
        run = super().run()
        return run


    def core_args(self):
        core_args = super().core_args()
        extra_args = [
            Argument(names=('foo', 'u'), help="Foo the bars"),
            # ...
        ]
        return core_args + extra_args

program = ChillboxProgram(namespace=Collection.from_module(tasks), version=__version__)



def chillbox_task(func):
    def wrap_task(*args, **kwargs):
        ""
        try:
            return func(*args, **kwargs)
        except ChillboxError as err:
            os.sys.exit(err)
    return wrap_task


def main():
    print('main')


# parse toml
# validate toml for required
# check for gpg key
#
if __name__ == "__main__":
    try:
        program.run()
    except ChillboxError as err:
        os.sys.exit(err)
