import os
import getpass
from shutil import which, rmtree, copyfileobj
from pathlib import Path
import importlib.resources as pkg_resources
from pprint import pformat
from tempfile import mkstemp, mkdtemp
from datetime import date
import tarfile
import gzip

from invoke import task
from jinja2 import Environment, PackageLoader, select_autoescape

from chillbox.validate import validate_and_load_chillbox_config, src_path_is_template
from chillbox.errors import (
    ChillboxServerUserDataError,
    ChillboxArchiveDirectoryError,
    ChillboxGPGError,
    ChillboxExpiredSecretError,
    ChillboxInvalidConfigError,
    ChillboxMissingFileError,
)
from chillbox.utils import logger, remove_temp_files, shred_file, encrypt_file, decrypt_file
import chillbox.data.scripts
from chillbox.template import Renderer
from chillbox.state import ChillboxState

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
    """"""
    gen_new_asymmetric_keys_script = pkg_resources.path(
        chillbox.data.scripts, "create-asymmetric-key"
    )
    result = c.run(
        f"{gen_new_asymmetric_keys_script} -n {name} -d {directory}", hide=True
    )
    logger.debug(result)

    private_key_cleartext = Path(directory).joinpath(f"{name}.private.pem").resolve()
    private_key_ciphertext = f"{private_key_cleartext}.gpg"
    result = c.run(
        f"gpg --encrypt --recipient {name} --output {private_key_ciphertext} {private_key_cleartext}",
        hide=True,
    )
    logger.debug(result)

    # TODO Secure delete the cleartext file with shred, srm, or some other solution.
    Path(private_key_cleartext).unlink()


def decrypt_file_with_gpg(c, ciphertext_gpg_file):
    """"""
    secure_temp_file = mkstemp(text=True)[1]
    # Use --yes to overwrite the tempfile
    result = c.run(
        f"gpg --yes --output {secure_temp_file} --decrypt {ciphertext_gpg_file}",
        hide=True,
    )
    return secure_temp_file


def init_local_chillbox_asymmetric_key(c, state):
    "Initialize the local chillbox asymmetric key"
    instance = c.chillbox_config["instance"]

    archive_directory_path = Path(c.chillbox_config["archive-directory"]).resolve()

    local_chillbox_asymmetric_key_dir = (
        Path(archive_directory_path).joinpath("local-chillbox-asymmetric").resolve()
    )
    Path(local_chillbox_asymmetric_key_dir).mkdir(
        mode=0o700, parents=True, exist_ok=True
    )

    gpg_encrypted_asymmetric_key_path = (
        Path(local_chillbox_asymmetric_key_dir)
        .joinpath(f"{instance}.private.pem.gpg")
        .resolve()
    )

    if not Path(gpg_encrypted_asymmetric_key_path).exists():
        create_and_encrypt_new_asymmetric_key(
            c, directory=local_chillbox_asymmetric_key_dir, name=instance
        )

    # Allow other tasks to use this key when decrypting other content. This way
    # the prompt to decrypt with gpg is no longer needed.
    c.local_chillbox_asymmetric_key_private = decrypt_file_with_gpg(
        c, gpg_encrypted_asymmetric_key_path
    )
    state.local_chillbox_asymmetric_key_private = c.local_chillbox_asymmetric_key_private
    logger.info("Set the local chillbox asymmetric key")



def encrypt_secrets_to_archive(c, state):
    """"""
    secret_list = c.chillbox_config.get("secret", [])
    logger.debug(secret_list)

    archive_directory = Path(c.chillbox_config["archive-directory"])

    today = date.today()
    logger.debug(state)
    for secret in secret_list:
        logger.debug(f"{secret=}")
        if secret.get("owner") != state.current_user:
            logger.info(
                f"Skipping the secret '{secret.get('id')}' since it is not owned by {state.current_user}."
            )
            continue
        secret_file_path = archive_directory.joinpath("secrets", secret["id"] + ".aes")
        expires_date = secret.get("expires")
        if secret_file_path.exists():
            if not expires_date:
                logger.info(
                    f"The secret '{secret.get('id')}' exists and has no expiration date."
                )
                continue
            elif today < expires_date:
                logger.info(
                    f"The secret '{secret.get('id')}' exists and has not expired."
                )
                continue
            else:
                raise ChillboxExpiredSecretError(
                    f"The secret '{secret.get('id')}' exists, but it has expired."
                )

        secret_in_cleartext = getpass.getpass(prompt=f"{secret.get('prompt')}\n")
        tmp_secret_file = mkstemp(text=True)[1]
        with open(tmp_secret_file, "w") as f:
            f.write(secret_in_cleartext)
        secret_file_path.parent.mkdir(parents=True, exist_ok=True)
        encrypt_file(c, tmp_secret_file, secret_file_path.resolve())
        shred_file(tmp_secret_file)


def load_env_vars(c):
    """
    Sets a c.env dict with these that can be used on c.run('cmd', env=c.env) calls.
    """
    # TODO: Ensure that values in the 'env' are all strings? Convert them to
    # strings if they are not?
    c.env = c.chillbox_config.get("env", {})


def load_secrets(c, state):
    """
    Similiar to load_env_vars, but sets c.secrets
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    secret_list = c.chillbox_config.get("secret", [])
    decrypt_file_script = pkg_resources.path(chillbox.data.scripts, "decrypt-file")

    secrets = {}
    for secret in secret_list:
        logger.debug(f"{secret=}")
        if secret.get("owner") != state.current_user:
            logger.info(
                f"Skipping the secret '{secret.get('id')}' since it is not owned by {state.current_user}."
            )
            continue
        secret_file_path = archive_directory.joinpath("secrets", secret["id"] + ".aes").resolve()
        secret_in_plaintext = decrypt_file(c, "-", secret_file_path)
        secrets[secret["name"]] = secret_in_plaintext

    c.secrets = secrets



def init_template_renderer(c):
    """"""
    template_list = c.chillbox_config.get("template", [])
    c.renderer = Renderer(template_list, c.working_directory)


def process_path_to_archive(c):
    """
    Process local files and directories to the chillbox archive 'path'
    directory.

    All processed paths are compressed (gzipped) and encrypted with
    the local chillbox asymmetric key. These files are then ready to be
    transferred to their remote destination (dest).

    Note that a different process will be used to decrypt the file and encrypt
    it using a different public key when transferring.  For example, with server
    remote destinations the public key of the server will be used to encrypt the
    file before uploading it with scp.
    """
    local_path_list = c.chillbox_config.get("path", [])
    logger.debug(local_path_list)
    instance = c.chillbox_config["instance"]
    archive_directory = Path(c.chillbox_config["archive-directory"])
    template_list = c.chillbox_config.get("template", [])
    public_asymmetric_key = archive_directory.joinpath(
        "local-chillbox-asymmetric", f"{instance}.public.pem"
    )

    errors = []
    # Set umask so files are only rw by owner.
    prev_umask = os.umask(0o077)
    for path in local_path_list:
        # TODO: Need to check if path is a directory
        file_errors = []
        secure_temp_file = Path(mkstemp(text=True)[1])
        id_path = archive_directory.joinpath("path", path["id"])
        id_path.parent.mkdir(parents=True, exist_ok=True)

        if path.get("render") and src_path_is_template(path["src"], template_list, c.working_directory):
            context = {}
            context.update(c.env)
            context.update(c.secrets)
            context.update(path.get("context", {}))
            with gzip.open(secure_temp_file, "wb") as f:
                f.write(bytes(c.renderer.render(path["src"], context), encoding="utf-8"))
        else:
            if path.get("render"):
                logger.warning(f"The path with id '{path['id']}' has 'render' set but path is not being processed as a template")
            if path.get("context"):
                logger.warning(f"The path with id '{path['id']}' has 'context' set but path is not being processed as a template.")
            src_path = Path(path["src"])
            if src_path.is_file():
                # Compress the file
                with open(src_path.resolve(), "rb") as fin:
                    with gzip.open(secure_temp_file, "wb") as fout:
                        copyfileobj(fin, fout)
            elif src_path.is_dir():
                # Create tar file
                with tarfile.open(secure_temp_file, "w:gz") as tar:
                    tar.add(src_path.resolve())

        encrypt_file(c, secure_temp_file, id_path.resolve())
        shred_file(secure_temp_file)

    if errors:
        template = env.get_template("local-process-path-errors.jinja")
        file_errors_message = template.render(**locals())
        raise ChillboxArchiveDirectoryError(
            f"ERROR: Failed to copy all local files to chillbox directory.\n{file_errors_message}"
        )

    # Return to previous umask
    os.umask(prev_umask)


def generate_password_hash(c, user):
    ""
    print(f"No password_hash set for user '{user}'. Enter new password for this user.")
    result = c.run(
        "openssl passwd -6", hide=True
    )
    return result.stdout.strip()

def user_password_hash_init(c, state):
    ""
    if state.current_user_data.get("password_hash"):
        return

    password_hash = generate_password_hash(c, state.current_user)
    if not password_hash:
        raise ChillboxServerUserDataError(f"No password_hash available for '{state.current_user}'")

    merged_current_user_data = {}
    merged_current_user_data.update(state.current_user_data)
    merged_current_user_data["password_hash"] = password_hash
    state.current_user_data = merged_current_user_data


def generate_and_encrypt_ssh_key(c, user):
    """
    Generate a private ssh key for the user and output the public key. The
    private ssh key will be encrypted with the local chillbox asymmetric key and
    stored in the chillbox archive directory. It is up to the user to ensure
    that these are properly backed up.
    """
    key_file_name = f"{user}.chillbox.pem"
    archive_directory = Path(c.chillbox_config["archive-directory"])
    encrypted_private_key_file = archive_directory.joinpath("ssh", key_file_name + ".aes")

    if encrypted_private_key_file.exists():
        raise ChillboxMissingFileError("ERROR: Not implemented. TODO: Handle the case if the statefile was deleted which had the public ssh key.")
        # plaintext_file = Path(mkstemp()[1])
        # decrypt_file(c, encrypted_private_key_file, plaintext_file)

        # result = c.run(f"ssh-keygen -f {plaintext_file} -y", hide=True)
        # shredfile(plaintext_file)
        # return result.stdout


    temp_dir = Path(mkdtemp())
    key_file = temp_dir.joinpath(key_file_name)

    result = c.run(
        f"ssh-keygen -t rsa -b 4096 -C '{user} - chillbox managed' -N '' -m 'PEM' -q -f '{key_file}'",
        hide=True,
    )
    logger.debug(result)
    private_key_file = key_file
    public_key_file = Path(f"{key_file}.pub")

    encrypted_private_key_file.parent.mkdir(parents=True, exist_ok=True)
    encrypt_file(c, private_key_file, encrypted_private_key_file)

    shred_file(private_key_file)
    public_key = public_key_file.read_text()
    public_key_file.unlink()
    temp_dir.rmdir()

    return public_key


def user_ssh_init(c, state):
    "Check current user and ensure that a public ssh key is available. Create one if not."
    logger.debug(f"{state.current_user=}")
    if not state.current_user:
        raise Exception(f"The current_user in state file has not been set. {state=}")

    key_file_name = f"{state.current_user}.chillbox.pem"
    archive_directory = Path(c.chillbox_config["archive-directory"])
    encrypted_private_key_file = archive_directory.joinpath("ssh", key_file_name + ".aes")

    merged_current_user_data = {}
    logger.debug(f"{c.chillbox_config.get('user')=}")
    current_user_match_list = list(filter(lambda x: x["name"] == state.current_user, c.chillbox_config.get("user", [])))
    if current_user_match_list:
        merged_current_user_data.update(current_user_match_list[0])
    else:
        raise Exception("Not handled")
    logger.debug(f"{current_user_match_list=}, {merged_current_user_data=}")
    merged_current_user_data.update(state.current_user_data)
    if not merged_current_user_data.get("public_ssh_key"):
        logger.warning(f"No public ssh key found for user '{state.current_user}'. Generating new private and public ssh keys now and storing them in the chillbox archive directory.")
        public_ssh_key = generate_and_encrypt_ssh_key(c, state.current_user)
        merged_current_user_data["public_ssh_key"] = [public_ssh_key]
    state.current_user_data = merged_current_user_data

    identity_file_temp = state.identity_file_temp
    if encrypted_private_key_file.exists() and not (identity_file_temp and Path(identity_file_temp).exists()):
        remove_temp_files(paths=[state.ssh_config_temp, identity_file_temp])
        private_ssh_key_file = Path(mkstemp()[1])
        decrypt_file(c, private_ssh_key_file, encrypted_private_key_file)
        state.identity_file_temp = str(private_ssh_key_file)

    user_password_hash_init(c, state)

@task
def init(c):
    "Initialize local archive directory as the current user"

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    # The working directory is always the directory containing the chillbox
    # config toml file.
    c.working_directory = Path(c.config["chillbox-config"]).resolve().parent

    archive_directory = Path(c.chillbox_config["archive-directory"]).resolve()

    # An owner needs to be set so this instance of the chillbox archive
    # directory will only create items that this user would need to manage.
    owner = getpass.getuser()
    if (
        archive_directory.exists()
        and not archive_directory.is_dir()
    ):
        raise ChillboxArchiveDirectoryError(
            f"ERROR: The archive path ({archive_directory}) needs to be a directory."
        )
    elif not archive_directory.exists():
        # Should only read/writable by owner
        archive_directory.mkdir(mode=0o700, parents=True)

    archive_owner = archive_directory.owner()
    if owner != archive_owner:
        raise ChillboxArchiveDirectoryError(
            f"ERROR: The archive directory owner needs to match the current user. The {archive_owner=} is not {owner=}"
        )

    state = ChillboxState(archive_directory)
    current_user = state.current_user
    if not current_user:
        current_user = input(f"No current_user has been set in state file. Set the current_user now or set to '{owner}'.\n  ")
        if not current_user:
            current_user = owner
        state.current_user = current_user
    logger.debug(f"{state.current_user=}")
    result = list(filter(lambda x: x["name"] == current_user, c.chillbox_config.get("user", [])))
    if not result:
        raise ChillboxInvalidConfigError(f"The current_user ({current_user}) has not been added to chillbox configuration file: {c.config['chillbox-config']}")

    # Set this so other tasks that have 'init' as a pre-task can use this value.
    c.archive_directory = archive_directory

    generate_gpg_key_or_use_existing(c)
    init_local_chillbox_asymmetric_key(c, state)
    encrypt_secrets_to_archive(c, state)
    load_env_vars(c)
    load_secrets(c, state)
    init_template_renderer(c)
    process_path_to_archive(c)
    user_ssh_init(c, state)


@task
def clean(c):
    "Delete local archive directory"

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])

    archive_directory = Path(c.chillbox_config["archive-directory"]).resolve()

    if not archive_directory.exists():
        logger.warning(
            f"No chillbox archive directory exists at path: {archive_directory}"
        )
        return

    confirm = input(
        f"Delete the chillbox archive directory at: {archive_directory} path? [y/n]\n"
    )
    if confirm == "y":
        try:
            rmtree(archive_directory)
        except Exception as err:
            raise ChillboxArchiveDirectoryError(err)
