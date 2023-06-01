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
from chillbox.defaults import CHILLBOX_PATH_SENSITIVE, CHILLBOX_PATH_SECRETS


def generate_user_data_script(c, state, replace_existing=False):
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
        if not replace_existing and user_data_script_file.exists():
            logger.info(
                f"Skipping replacement of existing user-data file: {user_data_script_file}"
            )
            continue

        result = list(
            filter(lambda x: x["name"] == current_user, c.chillbox_config["user"])
        )
        if not result:
            logger.warning(f"No user name matches with server owner ({server_owner})")
            continue

        # TODO Check if the user has a public ssh key set? Generate new one if
        # they don't and save public ssh key to statefile. The private key
        # should be encrypted with the gpg key (Already managed by chillbox?).

        server_user_data_context = {
            "chillbox_user": state.current_user_data,
            "chillbox_server": server,
        }
        server_user_data_context.update(deepcopy(dict(c.env)))

        # The server user-data context should not get c.secrets. The user-data
        # is not encrypted.
        server_user_data_context.update(server_user_data.get("context", {}))

        logger.debug(f"{server_user_data_context=}")
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
        public_ssh_key_file.write_text(
            "\n".join(state.current_user_data["public_ssh_key"])
        )


@task(pre=[init])
def server_init(c, force=False):
    """
    Initialize files that will be needed for the chillbox servers.

    The 'force' option will replace any existing user-data scripts.
    """

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    generate_user_data_script(c, state, replace_existing=force)
    output_current_user_public_ssh_key(c, state)


@task(pre=[server_init])
def upload(c):
    """
    Upload path objects and secrets to all servers that include them
    """
    # Note that the docstring is extended after the def.

    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    server_list = c.chillbox_config.get("server", [])
    ssh_config_file = state.ssh_config_temp
    is_ssh_unlocked = bool(ssh_config_file and Path(ssh_config_file).exists())
    user_server_list = get_user_server_list(server_list, state.current_user)

    path_mapping = dict(map(lambda x: (x["id"], x), c.chillbox_config.get("path", [])))
    secret_mapping = dict(
        map(lambda x: (x["id"], x), c.chillbox_config.get("secret", []))
    )

    def upload_sensitive_path(rc_scp, path, dest, public_asymmetric_key):
        """"""
        tmp_plaintext_file = mkstemp()[1]
        tmp_remote_ciphertext_file = mkstemp()[1]
        local_ciphertext_file = archive_directory.joinpath("path", path["id"])
        decrypt_file(c, tmp_plaintext_file, local_ciphertext_file)
        encrypt_file(
            c,
            tmp_plaintext_file,
            tmp_remote_ciphertext_file,
            public_asymmetric_key=public_asymmetric_key,
        )
        logger.info(f"Uploading sensitive encrypted gzipped file to {dest}")
        rc_scp.put(tmp_remote_ciphertext_file, remote_path=dest)
        remove_temp_files([tmp_plaintext_file, tmp_remote_ciphertext_file])

    def upload_path(rc_scp, path, dest):
        """"""
        tmp_plaintext_file = mkstemp()[1]
        local_ciphertext_file = archive_directory.joinpath("path", path["id"])
        decrypt_file(c, tmp_plaintext_file, local_ciphertext_file)
        logger.info(f"Uploading gzipped file to {dest}")
        rc_scp.put(tmp_plaintext_file, remote_path=dest)
        remove_temp_files([tmp_plaintext_file])

    if not is_ssh_unlocked:
        ssh_config_file = generate_ssh_config_temp(
            c, current_user=state.current_user, identity_file=state.identity_file_temp
        )

    config = Config(runtime_ssh_path=ssh_config_file)
    for server in user_server_list:
        logger.debug(f"{server=}")
        password_for_user = getpass(
            f"password for user '{state.current_user}' on the server '{server['name']}': "
        )
        rc = Connection(
            server["name"],
            config=config,
            connect_kwargs={"password": password_for_user},
            user=state.current_user,
        )
        rc.open()
        ssh_transport = rc.client.get_transport()
        tmp_server_pub_key = mkstemp()[1]

        with SCPClient(ssh_transport) as rc_scp:
            # Depends on the user-data script to have made a public asymmetric
            # key at this location.
            rc_scp.get(
                f"/usr/local/share/chillbox/key/{server['name']}.public.pem",
                local_path=tmp_server_pub_key,
            )

            # Build secret files to upload
            secret_dest_file_mapping = {}
            for secret_id in server.get("secrets", []):
                secret = secret_mapping.get(secret_id)
                if not secret:
                    logger.warning(f"No secret with id '{secret_id}'")
                    continue
                if secret.get("owner") and secret.get("owner") != state.current_user:
                    logger.info(
                        f"Skipping upload of secret '{secret_id}' because it is not owned by '{state.current_user}'."
                    )
                    continue
                secret_remote_list = secret.get("remote", [])
                if not secret_remote_list:
                    logger.warning(
                        f"No secret remote list set for secret with id '{secret_id}'"
                    )
                    continue
                for secret_remote in secret_remote_list:
                    append_dest = secret_remote.get("append-dest")
                    if not append_dest:
                        logger.error(
                            f"No secret remote append-dest set for secret with id '{secret_id}'"
                        )
                        # TODO: Handle this error in the validate step.
                        continue
                    if not secret_dest_file_mapping.get(append_dest):
                        secret_dest_file_mapping[append_dest] = []
                    secret_file_path = archive_directory.joinpath(
                        "secrets", secret["id"] + ".aes"
                    ).resolve()
                    secret_in_plaintext = decrypt_file(c, "-", secret_file_path)
                    secret_dest_file_mapping[append_dest].append(
                        f"{secret.get('name', secret['id'])}={secret_in_plaintext}"
                    )

            # Upload the built secrets
            for append_dest, secret_content_list in secret_dest_file_mapping.items():
                tmp_secret_plaintext_file = mkstemp()[1]
                Path(tmp_secret_plaintext_file).write_text(
                    "\n".join(secret_content_list)
                )

                tmp_secret_remote_ciphertext_file = mkstemp()[1]
                encrypt_file(
                    c,
                    tmp_secret_plaintext_file,
                    tmp_secret_remote_ciphertext_file,
                    public_asymmetric_key=tmp_server_pub_key,
                )
                target_path = f"{c.env['CHILLBOX_PATH_SECRETS']}/{state.current_user}{append_dest}"
                logger.info(f"Uploading secret encrypted file to {target_path}")
                parent_dir = Path(target_path).resolve(strict=False).parent
                rc.run(f"mkdir -p {parent_dir}")
                rc_scp.put(tmp_secret_remote_ciphertext_file, remote_path=target_path)
                remove_temp_files(
                    [tmp_secret_plaintext_file, tmp_secret_remote_ciphertext_file]
                )

            # All local paths are encrypted, but only re-encrypt them to the
            # server public key if they are sensitive (contain secrets) before
            # uploading.
            for remote_file_id in server.get("remote-files", []):
                path = path_mapping.get(remote_file_id)
                if not path:
                    logger.warning(f"No path with id '{remote_file_id}'")
                    continue

                if path.get("owner") and path.get("owner") != state.current_user:
                    logger.info(
                        f"Skipping upload of path '{remote_file_id}' because it is not owned by '{state.current_user}'."
                    )
                    continue

                target_path = (
                    path["dest"]
                    if not path.get("sensitive")
                    else f"{c.env['CHILLBOX_PATH_SENSITIVE']}/{state.current_user}{path['dest']}"
                )
                parent_dir = Path(target_path).resolve(strict=False).parent
                rc.run(f"mkdir -p {parent_dir}")

                if path.get("sensitive"):
                    upload_sensitive_path(
                        rc_scp,
                        path,
                        dest=target_path,
                        public_asymmetric_key=tmp_server_pub_key,
                    )
                else:
                    result = rc.run(f"mktemp", hide=True)
                    tmp_upload_path = result.stdout.strip()
                    upload_path(rc_scp, path, dest=tmp_upload_path)
                    if Path(path["src"]).is_dir():
                        logger.info(
                            f"Unzipping and extracting tar file {tmp_upload_path} to {target_path}"
                        )
                        target_dir = Path(target_path).resolve(strict=False)
                        rc.run(f"mkdir -p {target_dir}")
                        rc.run(f"chmod u+w {target_dir}")
                        rc.run(
                            f"tar x -z -f {tmp_upload_path} -C {target_dir} --strip-components 1"
                        )
                    else:
                        logger.info(
                            f"Unzipping file {tmp_upload_path} to {target_path}"
                        )
                        rc.run(f"touch {target_path} || echo \"can't touch this\"")
                        rc.run(f"chmod u+w {target_path}")
                        rc.run(f"gunzip -c -f {tmp_upload_path} > {target_path}")
                    rc.run(f"rm -rf {tmp_upload_path}")
            rc.run(f"touch {c.env['CHILLBOX_PATH_SECRETS_AND_SENSITIVE_LAST_UPDATE']} || echo \"can't touch this\"")
        rc.close()

    # Clean up
    if not is_ssh_unlocked:
        cleanup_ssh_config_temp(state)


upload.__doc__ = f"""
{upload.__doc__.strip()}

- The path objects that are set as 'sensitive' are encrypted to the server's
  public asymmetric key. The actual destination on the server will be:
  {CHILLBOX_PATH_SENSITIVE}/$CURRENT_USER$DEST where
  '$CURRENT_USER' and '$DEST' are replaced.

- Path objects that are files and are not sensitive are uploaded to the set
  'dest'.

- Path objects that have a 'src' as a directory are stored as an archive
  file. These will be extracted to the 'dest' on the server with the 'dest'
  always being a directory; the contents of the 'src' will be placed in the
  'dest'.

- The secrets are encrypted to the server's public asymmetric key. The actual
  destination on the server will be: {CHILLBOX_PATH_SECRETS}/$CURRENT_USER$APPEND_DEST
  where '$CURRENT_USER' and '$APPEND_DEST' are replaced.
"""
