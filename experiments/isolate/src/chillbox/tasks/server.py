from pathlib import Path

from invoke import task
from jinja2 import Environment, PackageLoader, select_autoescape

@task
def server_init(c):
    "Initialize files that will be needed for the chillbox servers."

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
