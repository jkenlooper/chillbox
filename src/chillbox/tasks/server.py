from pathlib import Path
import hashlib
from tempfile import mkstemp, mkdtemp
import bz2
from shutil import copyfileobj
from copy import deepcopy

from invoke import task
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

from chillbox.tasks.local_archive import init
from chillbox.validate import validate_and_load_chillbox_config
from chillbox.utils import (
    logger,
    encrypt_file,
    shred_file,
)
from chillbox.errors import (
    ChillboxMissingFileError,
    ChillboxServerUserDataError,
    ChillboxDependencyError,
)
from chillbox.local_checks import check_optional_commands

ephemeral_local_server_defaults = {
    "base_image_url": "https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2023-01-21-2310/alpine-virt-image-2023-01-21-2310.qcow2.bz2",
    "user_data_path": "/root/user-data",
    "public_ssh_keys_path": "/root/.ssh/authorized_keys",
}

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

def generate_password_hash(c, user):
    ""
    print(f"No password_hash set for user '{user}'. Enter new password for this user.")
    result = c.run(
        "openssl passwd -6", hide=True
    )
    return result.stdout.strip()

def user_password_hash_init(c):
    ""
    current_user = c.state["current_user"]

    current_user_data = list(filter(lambda x: x["name"] == current_user, c.chillbox_config.get("user", [])))[0]
    state_current_user_data = c.state.get("current_user_data", {})
    current_user_data.update(state_current_user_data)
    if not current_user_data.get("password_hash"):
        password_hash = generate_password_hash(c, current_user)
        state_current_user_data["password_hash"] = password_hash
        c.state["current_user_data"] = state_current_user_data


def user_ssh_init(c):
    "Check current user and ensure that a public ssh key is available. Create one if not."
    current_user = c.state["current_user"]

    current_user_data = list(filter(lambda x: x["name"] == current_user, c.chillbox_config.get("user", [])))[0]
    state_current_user_data = c.state.get("current_user_data", {})
    current_user_data.update(state_current_user_data)
    if not current_user_data.get("public_ssh_key"):
        logger.warning(f"No public ssh key found for user '{current_user}'. Generating new private and public ssh keys now and storing them in the chillbox archive directory.")
        public_ssh_key = generate_and_encrypt_ssh_key(c, current_user)
        state_current_user_data["public_ssh_key"] = [public_ssh_key]
        c.state["current_user_data"] = state_current_user_data


def generate_user_data_script(c):
    """"""
    server_list = c.chillbox_config.get("server", []) + c.chillbox_config.get("ephemeral-local-server", [])
    archive_directory = Path(c.chillbox_config["archive-directory"])
    current_user = c.state["current_user"]

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

        # TODO public ssh key should be of the current_user
        result = list(filter(lambda x: x["name"] == current_user, c.chillbox_config["user"]))
        if not result:
            logger.warning(f"No user name matches with server owner ({server_owner})")
            continue
        current_user_data = result[0]

        # TODO Check if the user has a public ssh key set? Generate new one if
        # they don't and save public ssh key to statefile. The private key
        # should be encrypted with the gpg key (Already managed by chillbox?).
        # TODO Check if the user has a password hash set? Generate new one if
        # they don't and store it in statefile. Password hash is not sensitive.

        server_user_data_context = {
            "chillbox_env": deepcopy(dict(c.env)),
            "chillbox_user": current_user_data,
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


@task(pre=[init])
def server_init(c):
    "Initialize files that will be needed for the chillbox servers."

    c.chillbox_config = validate_and_load_chillbox_config(c.config["chillbox-config"])
    user_ssh_init(c)
    user_password_hash_init(c)
    generate_user_data_script(c)


def get_hash_of_url(url):
    try:
        r = httpx.head(
            url,
            follow_redirects=True,
        )
        r.raise_for_status()
    except httpx.HTTPError as err:
        raise ChillboxHTTPError(f"ERROR: Request failed. {err}")
    logger.info(f"Successful HEAD response from {url}")
    return r.headers.get(
        "etag", hashlib.sha512(bytes(url, encoding="utf-8")).hexdigest()
    )


def fetch_url_to_tempfile(url):
    try:
        r = httpx.get(
            url,
            follow_redirects=True,
        )
        r.raise_for_status()
    except httpx.HTTPError as err:
        raise ChillboxHTTPError(f"ERROR: Request failed. {err}")
    logger.info(f"Successful GET response from {url}")

    t_file = mkstemp()[1]
    with open(t_file, "wb") as f:
        f.write(r.content)
    return t_file


@task(pre=[server_init])
def provision_local_server(c):
    "Provision ephemeral local servers with QEMU virtualization software."

    archive_directory = Path(c.chillbox_config["archive-directory"])
    base_images = c.state.get("base_images", {})
    server_images = c.state.get("server_images", {})

    # Setting up and using QEMU require _most_ of the optional commands.
    try:
        check_optional_commands()
    except ChillboxDependencyError as err:
        logger.warning(err)
        logger.warning(
            f"Executing some scripts may fail because there are some optional commands missing."
        )

    ephemeral_local_server_list = c.chillbox_config.get("ephemeral-local-server", [])
    if ephemeral_local_server_list:
        result = c.run("sudo ip addr del 169.254.169.254/32 dev lo", hide=True, warn=True)
        result = c.run("sudo ip addr add 169.254.169.254/32 dev lo", hide=True)

    for ephemeral_local_server in ephemeral_local_server_list:
        s = ephemeral_local_server_defaults.copy()
        s.update(ephemeral_local_server)
        server_name = s["name"]

        base_image_url = s["base_image_url"]
        hash_url = get_hash_of_url(base_image_url)
        base_image = base_images.get(base_image_url, {})
        base_image_temp_file = base_image.get("temp_file")
        if (
            not base_image
            or hash_url != base_image.get("hash_url")
            or not base_image_temp_file
            or not Path(base_image_temp_file).exists()
        ):
            base_image_temp_file = fetch_url_to_tempfile(base_image_url)
            base_images[base_image_url] = {"hash_url": hash_url, "temp_file": base_image_temp_file}

        server_image_temp_file = server_images.get(server_name)
        if not server_image_temp_file or not Path(server_image_temp_file).exists():
            tmp_server_dir = Path(mkdtemp())

            hostname_file = tmp_server_dir.joinpath("metadata", "v1", "hostname")
            hostname_file.parent.mkdir(parents=True, exist_ok=True)
            hostname_file.write_text(server_name)

            public_keys_file = tmp_server_dir.joinpath("metadata", "v1", "public-keys")
            public_keys_file.parent.mkdir(parents=True, exist_ok=True)
            public_keys_file.write_text("\n".join(c.state["current_user_data"]["public_ssh_key"]))

            user_data = archive_directory.joinpath("server", server_name, "user-data").read_text()
            user_data_file = tmp_server_dir.joinpath("metadata", "v1", "user-data")
            user_data_file.parent.mkdir(parents=True, exist_ok=True)
            user_data_file.write_text(user_data)

            # Not used, but need a file here anyways.
            ipv4_address_file = tmp_server_dir.joinpath("metadata", "v1", "interfaces", "public", "0", "ipv4", "address")
            ipv4_address_file.parent.mkdir(parents=True, exist_ok=True)
            ipv4_address_file.write_text("")

            print(f"sudo python -m http.server --directory '{tmp_server_dir}' --bind 169.254.169.254 80")
            print(f"rm -rf '{tmp_server_dir}'")
            confirm = input("continue?")

            server_image_temp_file = mkstemp()[1]
            with bz2.open(base_image_temp_file, "rb") as fin:
                with open(server_image_temp_file, "wb") as fout:
                    copyfileobj(fin, fout)

            server_images[server_name] = server_image_temp_file

            #virt-customize -a "$image_dir/$image_file" --upload path-to/server/user-data:/root/user-data
            # /etc/hostname
            # /root/.ssh/authorized_keys
            # /root/user-data

        # store the port in statefile and configure ssh config to connect

        # start virt machine? Or should only start if --local was passed to remote task?
        c.run(
            f"""
qemu-system-x86_64 \
-machine type=q35,accel=tcg \
-smp 4 \
-hda '{server_image_temp_file}' \
-m 8G \
-vga virtio \
-usb \
-device usb-tablet \
-daemonize \
-net user,hostfwd=tcp::10022-:22 \
-net nic
            """,
            warn=False, hide=True,
            disown=True,
        )

    c.state["base_images"] = base_images
    c.state["server_images"] = server_images
