import tempfile
from pathlib import Path

from chillbox.utils import (
    logger,
    remove_temp_files,
    get_template,
    get_user_server_list,
)


def generate_ssh_config_temp(c, current_user, identity_file):
    """
    The temporary ssh_config file will be automatically created based on
    information found in the chillbox configuration. The identity file is the
    private ssh key if one was created specifically for the user.
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    user_known_hosts_file = archive_directory.joinpath("ssh_known_hosts").resolve()
    server_list = c.chillbox_config.get("server", [])

    user_server_list = get_user_server_list(server_list, current_user)

    ssh_config = tempfile.mkstemp(suffix=".chillbox.ssh_config")[1]
    logger.debug(f"{ssh_config=}")

    # Include a user managed ssh_config file if it was set. Useful for
    # local development and using a Vagrant managed ssh_config file.
    user_managed_ssh_config_path = Path(c.chillbox_config.get("ssh_config", ""))
    user_managed_ssh_config = False
    if user_managed_ssh_config_path.is_file():
        user_managed_ssh_config = user_managed_ssh_config_path.read_text()

    template = get_template("ssh_config.jinja")
    with open(ssh_config, "w") as f:
        f.write(
            template.render(
                {
                    "ssh_config": ssh_config,
                    "current_user": current_user,
                    "known_hosts_file": user_known_hosts_file,
                    "identity_file": identity_file,
                    "user_server_list": user_server_list,
                    "user_managed_ssh_config": user_managed_ssh_config,
                }
            )
        )

    return ssh_config


def cleanup_ssh_config_temp(state):
    """"""
    # Always delete any older ones first
    remove_temp_files(paths=[state.ssh_config_temp, state.identity_file_temp])
    state.ssh_config_temp = None
    state.identity_file_temp = None
