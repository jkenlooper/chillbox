import os
import logging
import json
from pathlib import Path
import subprocess
import importlib.resources as pkg_resources

from jinja2 import FileSystemLoader, Environment, PackageLoader, select_autoescape

import chillbox.data.scripts
from chillbox.errors import (
    ChillboxInvalidStateFileError,
    ChillboxTemplateError,
    ChillboxExit,
)

LOG_FORMAT = "%(levelname)s: %(name)s.%(module)s.%(funcName)s:\n  %(message)s"
logging.basicConfig(level=logging.WARNING, format=LOG_FORMAT)
# Allow invoke debugging mode if the env var is set for it.
logger = logging.getLogger(
    "chillbox" if not os.environ.get("INVOKE_DEBUG") else "invoke"
)

env = Environment(loader=PackageLoader("chillbox"), autoescape=select_autoescape())


def get_template(file):
    "Return a jinja template from chillbox templates directory."
    template = env.get_template(file)
    return template


def shred_file(file):
    """
    Overwrite data first before unlinking to more securely delete sensitive
    information like secrets. Uses the 'shred' command, but falls back on
    unlinking if that fails.
    """

    if not Path(file).exists():
        logger.warning(f"The file ({file}) does not exist. Nothing to shred.")
        return
    if Path(file).is_dir():
        raise ChillboxExit(f"ERROR: The path ({file}) is a directory. Shredding files in a directory is not supported.")

    try:
        result = subprocess.run(
            ["shred", "-fuz", str(file)], capture_output=True, check=True, text=True
        )
        logger.debug(result)
    except FileNotFoundError as err:
        logger.warning(f"Failed to properly shred {file} file.\n  {err}")
    except subprocess.CalledProcessError as err:
        logger.warning(f"Failed to properly shred {file} file.\n  {err}")
    finally:
        if Path(file).exists():
            logger.warning(f"Only performing an unlink of the {file} file.")
            Path(file).unlink()


def remove_temp_files(paths=[]):
    for f in paths:
        if f and Path(f).exists():
            shred_file(f)


def get_file_system_loader(src, working_directory):
    src_path = working_directory.joinpath(src).resolve()
    if not src_path.is_relative_to(working_directory):
        raise ChillboxTemplateError(
            f"ERROR: The template src path ({src_path}) is outside the working directory: {working_directory.resolve()}"
        )
    if not src_path.is_dir():
        raise ChillboxTemplateError(
            f"ERROR: The template src path is not a directory: {src_path.resolve()}"
        )
    return FileSystemLoader(src_path)


def encrypt_file(c, plaintext_file, ciphertext_file, public_asymmetric_key=None):
    "Wrapper around chillbox encrypt-file script that uses the local-chillbox-asymmetric public key."
    archive_directory = Path(c.chillbox_config["archive-directory"])
    instance = c.chillbox_config["instance"]
    encrypt_file_script = pkg_resources.path(chillbox.data.scripts, "encrypt-file")
    if public_asymmetric_key is None:
        public_asymmetric_key = archive_directory.joinpath(
            "local-chillbox-asymmetric", f"{instance}.public.pem"
        ).resolve()

    result = c.run(
        f"{encrypt_file_script} -k {public_asymmetric_key} -o {ciphertext_file} {plaintext_file}",
        hide=True,
    )
    logger.debug(result)


def decrypt_file(c, plaintext_file, ciphertext_file):
    "Wrapper around chillbox decrypt-file script that uses the local-chillbox-asymmetric private key."
    decrypt_file_script = pkg_resources.path(chillbox.data.scripts, "decrypt-file")

    if not Path(c.local_chillbox_asymmetric_key_private).exists():
        # The decrypt_file is located here because encrypt_file is also here.
        # The private asymmetric key is removed at the end of the chillbox
        # program to keep it safe since it is encrypted with the gpg key. Raise
        # an exception here in case there is code that tries to decrypt
        # something without having the private key available.
        raise RuntimeError("ERROR: The local chillbox asymmetric private key does not exist. Has it been decrypted?")

    result = c.run(
        f"{decrypt_file_script} -k {c.local_chillbox_asymmetric_key_private} -i {ciphertext_file} {plaintext_file}",
        hide=True,
    )
    if plaintext_file == "-":
        return result.stdout


def get_user_server_list(server_list, current_user):
    ""
    def user_has_access(server):
        "The current user has access to a server if they are the owner or in the list of login-users."
        if server.get("owner") and server.get("owner") == current_user:
            return True
        login_users = server.get("login-users", [])
        return any(map(lambda x: x == current_user, login_users))

    user_server_list = list(filter(user_has_access, server_list))
    return user_server_list

