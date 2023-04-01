from invoke import task

from chillbox.tasks.local_archive import init


@task(pre=[init])
def output_env(c):
    """
    Output local environment variables and secrets.

    The format of the output is VARIABLE_NAME='value' per line.
    Example use case:
        set -a; eval '$(chillbox output-env)'; set +a
        ./run-some-other-script.sh

    Don't need to use 'export' in front of these if the 'set -a' is used. This
    also makes it more versatile since the output could be sent to a temporary
    file. That temp file could be used as an env file for docker.
    """

    # The chillbox archive directory should probably *not* be accessed by
    # outside scripts.
    # CHILLBOX_ARCHIVE_DIRECTORY="{c.archive_directory_path}"

    # CHILLBOX_PRIVATE_SSH_KEY="?"

    # It *could* be useful to export the chillbox instance name?

    # TODO Include other env vars and secrets here.
    print(
        f"""
CHILLBOX_INSTANCE="{c.chillbox_config['instance']}"

# use via: ssh -F $CHILLBOX_SSH_CONFIG
CHILLBOX_SSH_CONFIG="chillbox-ssh_config"

TEST="test of string 1"
"""
    )
