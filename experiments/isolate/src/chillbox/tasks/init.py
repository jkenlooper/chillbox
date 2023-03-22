from shutil import which

from invoke import task

from chillbox.tasks.validate import validate_chillbox_config


@task(pre=[validate_chillbox_config])
def init(c, owner=None):

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
