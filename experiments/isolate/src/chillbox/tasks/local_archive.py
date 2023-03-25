from shutil import which
from pathlib import Path

from invoke import task

from chillbox.tasks.validate import validate_and_load_chillbox_config


@task(pre=[validate_and_load_chillbox_config])
def init(c, owner=None):
    "Initialize local archive directory as the current user"
    # An owner needs to be set so this instance of the chillbox archive
    # directory will only create items that this user would need to manage.
    if owner is None:
        if which("whoami"):
            owner = c.run("whoami", hide="stdout").stdout
        else:
            # You are you, but who am I?
            owner = "uru"
            print("TODO: Throw a warning here if the owner can't be determined?")

    c.run("echo 'TODO: Check for archive directory'")
    c.run("echo 'TODO: Init archive directory with owner'")


@task(pre=[validate_and_load_chillbox_config])
def clean(c):
    "Delete local archive directory"

    archive_directory_path = Path(c.chillbox_config["archive-directory"]).resolve()

    c.run(
        f"echo 'TODO: Prompt to confirm deletion of directory at {archive_directory_path}'"
    )
