import tempfile
from pathlib import Path

from chillbox.utils import (
    logger,
    remove_temp_files,
    get_template,
    get_user_server_list,
)


def generate_ssh_config_temp(c):
    """
    The temporary ssh_config file will be automatically created based on
    information found in the chillbox configuration. The identity file is the
    private ssh key if one was created specifically for the user.
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    user_known_hosts_file = archive_directory.joinpath("ssh_known_hosts").resolve()
    identity_file = c.state.get("identity_file_temp")
    current_user = c.state["current_user"]

    user_server_list = get_user_server_list(c)

    ssh_config = tempfile.mkstemp(suffix=".chillbox.ssh_config")[1]
    logger.debug(f"{ssh_config=}")

    template = get_template("ssh_config.jinja")
    with open(ssh_config, "w") as f:
        f.write(template.render({
            "ssh_config": ssh_config,
            "current_user": current_user,
            "known_hosts_file": user_known_hosts_file,
            "identity_file": identity_file,
            "user_server_list": user_server_list,
        }))

    return ssh_config


def cleanup_ssh_config_temp(c):
    ""

    archive_directory = Path(c.chillbox_config["archive-directory"])
    ssh_config = c.state.get("ssh_config_temp")
    identity_file = c.state.get("identity_file_temp")

    # Always delete any older ones first
    remove_temp_files(paths=[ssh_config, identity_file])

    del c.state["ssh_config_temp"]
    del c.state["identity_file_temp"]
