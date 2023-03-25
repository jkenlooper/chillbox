import os
from shutil import which, rmtree
from pathlib import Path
import importlib.resources as pkg_resources
from pprint import pformat

from invoke import task
from jinja2 import Environment, PackageLoader, select_autoescape

from chillbox.validate import validate_and_load_chillbox_config
from chillbox.errors import ChillboxArchiveDirectoryError, ChillboxGPGError
from chillbox.utils import logger
import chillbox.data.scripts

env = Environment(loader=PackageLoader("chillbox"), autoescape=select_autoescape())

def generate_gpg_key_or_use_existing(c):
    gpg_key_name = c.chillbox_config["gpg-key"]

    result = c.run(
        f"gpg --textmode --list-secret-keys '{gpg_key_name}'", warn=True, hide=True
    )
    logger.info(result)
    if result.exited == 2 and "No secret key" in result.stderr:
        logger.info(
            f"No existing gpg key found for {gpg_key_name}. Creating new one now."
        )
    elif result.exited == 0:
        logger.info(f"Found existing gpg key with name {gpg_key_name}.")
        return
    else:
        raise ChillboxGPGError(
            f"ERROR: The gpg command failed:\n  {result.command}\n  {result.stderr}"
        )

    result = c.run(
        f"gpg --quick-generate-key '{gpg_key_name}' default encrypt never",
        warn=True,
        hide=True,
    )
    logger.info(result)
    if result.exited == 0:
        logger.info(f"Created new gpg key with name {gpg_key_name}.")
    else:
        raise ChillboxGPGError(
            f"ERROR: The gpg command failed:\n  {result.command}\n  {result.stderr}"
        )

def create_and_encrypt_new_asymmetric_key(c, directory, name):
    ""
    gen_new_symmetric_keys_script = pkg_resources.path(chillbox.data.scripts, "generate-new-chillbox-keys")
    result = c.run(f"{gen_new_symmetric_keys_script} -n {name} -d {directory}", hide=True)
    logger.debug(result)

    private_key_cleartext = Path(directory).joinpath(f"{name}.private.pem").resolve()
    private_key_ciphertext = f"{private_key_cleartext}.gpg"
    result = c.run(f"gpg --encrypt --recipient {name} --output {private_key_ciphertext} {private_key_cleartext}", hide=True)
    logger.debug(result)

    # TODO Secure delete the cleartext file with shred, srm, or some other solution.
    Path(private_key_cleartext).unlink()

def decrypt_file_with_gpg(c, ciphertext_gpg_file):
    ""
    result = c.run(f"gpg --decrypt {ciphertext_gpg_file}", hide=True)
    logger.debug(result)
    return result.stdout

def init_local_chillbox_asymmetric_key(c):
    "Initialize the local chillbox asymmetric key"
    gpg_key_name = c.chillbox_config["gpg-key"]
    instance = c.chillbox_config["instance"]

    archive_directory_path = Path(c.chillbox_config["archive-directory"]).resolve()

    local_chillbox_asymmetric_key_dir = Path(archive_directory_path).joinpath("local-chillbox-asymmetric").resolve()
    Path(local_chillbox_asymmetric_key_dir).mkdir(mode=0o700, parents=True, exist_ok=True)

    gpg_encrypted_asymmetric_key_path = Path(local_chillbox_asymmetric_key_dir).joinpath(f"{instance}.private.pem.gpg").resolve()

    if not Path(gpg_encrypted_asymmetric_key_path).exists():
        create_and_encrypt_new_asymmetric_key(c, directory=local_chillbox_asymmetric_key_dir, name=instance)

    # Allow other tasks to use this key when decrypting other content. This way
    # the prompt to decrypt with gpg is no longer needed.
    c.local_chillbox_asymmetric_key_private = decrypt_file_with_gpg(c, gpg_encrypted_asymmetric_key_path)
    logger.info("Set the local chillbox asymmetric key")

def copy_local_files_to_archive(c):
    "Copy local files to the chillbox archive directory"
    local_file_list = c.chillbox_config["local-file"]
    logger.debug(local_file_list)
    archive_directory_path = Path(c.chillbox_config["archive-directory"]).resolve()

    errors = []
    for f in local_file_list:
        file_errors = []
        src_path = Path(f["src"])
        if not src_path.exists():
            file_errors.append(f"The src path does not exist: {src_path.resolve()}")
        dest_path = Path(f["dest"])
        if not dest_path.is_relative_to(archive_directory_path):
            file_errors.append(f"The dest path is not relative to: {archive_directory_path}")
        if file_errors:
            errors.append({"file": f, "msg": file_errors})
            continue
    logger.debug(errors)
    if errors:
        template = env.get_template("local-copy-files-errors.jinja2")
        file_errors_message = template.render(**locals())
        raise ChillboxArchiveDirectoryError(f"ERROR: Failed to copy all local files to chillbox directory.\n{file_errors_message}")


@task
def init(c):
    "Initialize local archive directory as the current user"

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])

    # An owner needs to be set so this instance of the chillbox archive
    # directory will only create items that this user would need to manage.
    if which("whoami"):
        owner = c.run("whoami", hide="stdout").stdout.strip()
    else:
        # You are you, but who am I?
        owner = "uru"
        print("TODO: Raise a warning here if the owner can't be determined?")

    archive_directory_path = Path(c.chillbox_config["archive-directory"]).resolve()

    if Path(archive_directory_path).exists() and not Path(archive_directory_path).is_dir():
        raise ChillboxArchiveDirectoryError(f"ERROR: The archive path ({archive_directory_path}) needs to be a directory.")
    elif not Path(archive_directory_path).exists():
        # Should only read/writable by owner
        Path(archive_directory_path).mkdir(mode=0o700, parents=True)

    archive_owner = Path(archive_directory_path).owner()
    if owner != archive_owner:
        raise ChillboxArchiveDirectoryError(f"ERROR: The archive directory owner needs to match the current user. The {archive_owner=} is not {owner=}")

    generate_gpg_key_or_use_existing(c)
    init_local_chillbox_asymmetric_key(c)
    copy_local_files_to_archive(c)
    # set_secrets_to_archive
    # set_env_to_archive

@task
def clean(c):
    "Delete local archive directory"

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])

    archive_directory_path = Path(c.chillbox_config["archive-directory"]).resolve()

    if not Path(archive_directory_path).exists():
        logger.warning(f"No chillbox archive directory exists at path: {archive_directory_path}")
        return

    confirm = input(f"Delete the chillbox archive directory at: {archive_directory_path} path? [y/n]\n")
    if confirm == "y":
        try:
            rmtree(archive_directory_path)
        except Exception as err:
            raise ChillboxArchiveDirectoryError(err)



