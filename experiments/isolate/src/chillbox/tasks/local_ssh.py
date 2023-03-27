import tempfile
import json
from pathlib import Path

from invoke import task

from chillbox.tasks.local_archive import init
from chillbox.utils import logger, get_state_file_data, save_state_file_data


def remove_temp_ssh_files(ssh_config, identity_file):
    if ssh_config and Path(ssh_config).exists():
        Path(ssh_config).unlink()
    if identity_file and Path(identity_file).exists():
        Path(identity_file).unlink()


@task(pre=[init])
def ssh_unlock(c):
    """
    Create a temporary ssh_config file and identity file that can be used for ssh commands.

    The temporary ssh_config file will be automatically created based on
    information found in the chillbox configuration. The identity file is the
    private ssh key if one was created specifically for the user.

    ## Example ssh_config file contents.
    ```
    StrictHostKeyChecking yes
    # For each server in the chillbox configuration, a Host block is created.
    Host {ipv4_address} {hostname}
      IdentityFile $TEMPDIR/temporary-path-to/chillbox.pem
      Hostname {hostname}
      # The owner is the same as the owner of the chillbox archive directory.
      User {owner}
    ```
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state_file_data = get_state_file_data(archive_directory)

    ssh_config = state_file_data.get("ssh_config_temp")
    identity_file = state_file_data.get("identity_file_temp")

    # Always delete any older ones first
    remove_temp_ssh_files(ssh_config, identity_file)

    ssh_config = tempfile.mkstemp(suffix=".chillbox.ssh_config")[1]
    state_file_data["ssh_config_temp"] = ssh_config
    logger.debug(f"{ssh_config=}")
    identity_file = tempfile.mkstemp(suffix=".chillbox.pem")[1]
    state_file_data["identity_file_temp"] = identity_file
    logger.debug(f"{identity_file=}")

    with open(ssh_config, "w") as f:
        f.write(
            """# TODO create ssh_config same way as src/terraform/020-chillbox/ansible_ssh_config.tftpl"""
        )

    with open(identity_file, "w") as f:
        f.write("""# TODO output the private ssh key that was generated here.""")

    logger.info(
        f"Generated a ssh_config file to use with ssh when connecting to a chillbox server. Replace CHILLBOX_SERVER_HOSTNAME with hostname of the server.\n  Use the ssh command:\n  ssh -F {ssh_config=} CHILLBOX_SERVER_HOSTNAME"
    )
    print(ssh_config)

    save_state_file_data(archive_directory, state_file_data)


@task(pre=[init])
def ssh_lock(c):
    """
    Remove temporary ssh_config file and identity file that was created for ssh commands.
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state_file_data = get_state_file_data(archive_directory)
    ssh_config = state_file_data.get("ssh_config_temp")
    identity_file = state_file_data.get("identity_file_temp")

    # Always delete any older ones first
    remove_temp_ssh_files(ssh_config, identity_file)

    del state_file_data["ssh_config_temp"]
    del state_file_data["identity_file_temp"]
    save_state_file_data(archive_directory, state_file_data)
