from pathlib import Path
import hashlib
from tempfile import mkstemp
import bz2
from shutil import copyfileobj
from copy import deepcopy
from getpass import getpass

from invoke import task
from fabric import Connection, Config
from jinja2 import (
    Environment,
    PrefixLoader,
    ChoiceLoader,
    PackageLoader,
    FileSystemLoader,
    select_autoescape,
)
from jinja2.exceptions import TemplateNotFound
import httpx
from scp import SCPClient

from chillbox.tasks.local_archive import init
from chillbox.validate import validate_and_load_chillbox_config
from chillbox.utils import (
    logger,
    encrypt_file,
    decrypt_file,
    shred_file,
    get_user_server_list,
    remove_temp_files,
)
from chillbox.errors import (
    ChillboxServerUserDataError,
    ChillboxDependencyError,
)
from chillbox.local_checks import check_optional_commands
from chillbox.ssh import generate_ssh_config_temp, cleanup_ssh_config_temp
from chillbox.state import ChillboxState


def generate_user_data_script(c, state):
    """"""
    server_list = c.chillbox_config.get("server", [])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    current_user = state.current_user

    for server in server_list:
        server_owner = server.get("owner")
        logger.debug(f"Server owner {server_owner}")
        if not server_owner or server_owner != current_user:
            continue
        server_user_data = server.get("user-data")
        if not server_user_data:
            continue
        server_user_data_template = server_user_data.get("template")
        if not server_user_data_template:
            continue

        user_data_script_file = archive_directory.joinpath(
            "server", server["name"], "user-data"
        )
        if user_data_script_file.exists():
            logger.info(f"Skipping replacement of existing user-data file: {user_data_script_file}")
            continue

        result = list(filter(lambda x: x["name"] == current_user, c.chillbox_config["user"]))
        if not result:
            logger.warning(f"No user name matches with server owner ({server_owner})")
            continue

        # TODO Check if the user has a public ssh key set? Generate new one if
        # they don't and save public ssh key to statefile. The private key
        # should be encrypted with the gpg key (Already managed by chillbox?).

        server_user_data_context = {
            "chillbox_env": deepcopy(dict(c.env)),
            "chillbox_user": state.current_user_data,
            "chillbox_server": server,
        }

        # The server user-data context should not get c.secrets. The user-data
        # is not encrypted.
        server_user_data_context.update(server_user_data.get("context", {}))

        user_data_text = c.renderer.render(
            server_user_data_template, server_user_data_context
        )

        user_data_script_file.parent.mkdir(parents=True, exist_ok=True)
        user_data_file_size_limit = server_user_data.get("file-size-limit")
        if (
            user_data_file_size_limit
            and len(user_data_text) >= user_data_file_size_limit
        ):
            logger.info(user_data_text)
            raise ChillboxServerUserDataError(
                f"ERROR: The rendered server ({server['name']}) user-data is over the file size limit. Limit is {user_data_file_size_limit} and user-data bytes is {len(user_data_text)}."
            )

        user_data_script_file.write_text(user_data_text)


def output_current_user_public_ssh_key(c, state):
    server_list = c.chillbox_config.get("server", [])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    current_user = state.current_user

    for server in server_list:
        server_owner = server.get("owner")
        if not server_owner or server_owner != current_user:
            continue

        public_ssh_key_file = archive_directory.joinpath(
            "server", server["name"], "public_ssh_key"
        )
        if public_ssh_key_file.exists():
            public_ssh_key_file.unlink()
        public_ssh_key_file.parent.mkdir(parents=True, exist_ok=True)
        public_ssh_key_file.write_text("\n".join(state.current_user_data["public_ssh_key"]))


@task(pre=[init])
def server_init(c):
    "Initialize files that will be needed for the chillbox servers."

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    generate_user_data_script(c, state)
    output_current_user_public_ssh_key(c, state)



@task(pre=[server_init])
def upload(c):
    ""
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    server_list = c.chillbox_config.get("server", [])
    ssh_config_file = state.ssh_config_temp
    is_ssh_unlocked = bool(ssh_config_file and Path(ssh_config_file).exists())
    user_server_list = get_user_server_list(server_list, state.current_user)

    path_mapping = dict(map(lambda x: (x["id"], x), c.chillbox_config.get("path", [])))


    def upload_sensitive_path(rc_scp, path, dest):
        ""
        tmp_plaintext_file = mkstemp()[1]
        tmp_remote_ciphertext_file = mkstemp()[1]
        local_ciphertext_file = archive_directory.joinpath("path", path["id"])
        decrypt_file(c, tmp_plaintext_file, local_ciphertext_file)
        encrypt_file(c, tmp_plaintext_file, tmp_remote_ciphertext_file, public_asymmetric_key=tmp_server_pub_key)
        rc_scp.put(tmp_remote_ciphertext_file, remote_path=dest)

        # TODO A running service on the server could be configured to watch
        # paths in /var/lib/chillbox/path_sensitive/* and automatically decrypt
        # the file to the dest location.

    def upload_path(rc_scp, path, dest):
        ""
        tmp_plaintext_file = mkstemp()[1]
        tmp_remote_ciphertext_file = mkstemp()[1]
        local_ciphertext_file = archive_directory.joinpath("path", path["id"])
        decrypt_file(c, tmp_plaintext_file, local_ciphertext_file)
        logger.debug(f"plaintext file {path['id']} \n{tmp_plaintext_file}")
        rc_scp.put(tmp_plaintext_file, remote_path=dest)
        remove_temp_files([tmp_plaintext_file])

    if not is_ssh_unlocked:
        ssh_config_file = generate_ssh_config_temp(c, current_user=state.current_user, identity_file=state.identity_file_temp)

    config = Config(runtime_ssh_path=ssh_config_file)
    for server in user_server_list:
        logger.debug(f"{server=}")
        password_for_user = getpass(f"password for user '{state.current_user}' on the server '{server['name']}': ")
        rc = Connection(server["name"], config=config, connect_kwargs={"password":password_for_user})
        rc.open()
        ssh_transport = rc.client.get_transport()
        tmp_server_pub_key = mkstemp()[1]

        with SCPClient(ssh_transport) as rc_scp:
            # Depends on the user-data script to have made a public asymmetric
            # key at this location.
            rc_scp.get(f"/usr/local/share/chillbox/key/{server['name']}.public.pem", local_path=tmp_server_pub_key)

            # TODO upload secrets

            # All local paths are encrypted, but only re-encrypt them to the
            # server public key if they are sensitive (contain secrets) before
            # uploading.
            for remote_file_id in server.get("remote-files", []):
                path = path_mapping.get(remote_file_id)
                if not path:
                    logger.warning(f"No path with id '{remote_file_id}'")
                    continue

                target_path = path["dest"] if not path.get("sensitive") else f"/var/lib/chillbox/path_sensitive/{state.current_user}/{path['dest']}"
                parent_dir = Path(target_path).resolve(strict=False).parent
                rc.run(f"mkdir -p {parent_dir}")
                result = rc.run(f"mktemp")
                tmp_upload_path = result.stdout.strip()

                if path.get("sensitive"):
                    upload_sensitive_path(rc_scp, path, dest=tmp_upload_path)
                else:
                    upload_path(rc_scp, path, dest=tmp_upload_path)
                rc.run(f"gunzip -c -f {tmp_upload_path} > {target_path}")
        rc.close()

    # Clean up
    if not is_ssh_unlocked:
        cleanup_ssh_config_temp(state)
