from pathlib import Path
import hashlib
from tempfile import mkstemp
import bz2
from shutil import copyfileobj

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
)

from chillbox.errors import (
    ChillboxMissingFileError,
    ChillboxServerUserDataError,
    ChillboxDependencyError,
)
from chillbox.local_checks import check_optional_commands

ephemeral_local_server_defaults = {
    "base-image-url": "https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2023-01-21-2310/alpine-virt-image-2023-01-21-2310.qcow2.bz2",
    "user-data-path": "/root/user-data",
    "public-ssh-keys-path": "/root/.ssh/authorized_keys",
}


def generate_user_data_script(c):
    """"""
    server_list = c.chillbox_config.get("server", []) + c.chillbox_config.get("ephemeral-local-server", [])
    logger.debug(server_list)
    archive_directory = Path(c.chillbox_config["archive-directory"])

    for server in server_list:
        server_user_data = server.get("user-data")
        if not server_user_data:
            continue
        server_user_data_template = server_user_data.get("template")
        if not server_user_data_template:
            continue
        server_user_data_context = {
            "public_ssh_keys": ["public ssh key"],
            "hostname": "",
            "login_users": [],
            "no_home_users": [],
        }

        server_user_data_context.update(c.env)
        # The server user-data context should not get c.secrets. The user-data
        # is not encrypted.
        server_user_data_context.update(server_user_data.get("context", {}))

        user_data_text = c.renderer.render(
            server_user_data_template, server_user_data_context
        )

        user_data_script_file = archive_directory.joinpath(
            "server", server["name"], "user-data"
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
    for ephemeral_local_server in ephemeral_local_server_list:
        s = ephemeral_local_server_defaults.copy()
        s.update(ephemeral_local_server)
        server_name = s["name"]

        base_image_url = s["base-image-url"]
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
            # virt-customize to add user-data, public ssh keys, hostname files.
            server_image_temp_file = mkstemp()[1]
            with bz2.open(base_image_temp_file, "rb") as fin:
                with open(server_image_temp_file, "wb") as fout:
                    copyfileobj(fin, fout)


            user_data = archive_directory.joinpath("server", server_name, "user-data").resolve()
            result = c.run(
                f"sudo virt-customize -a '{server_image_temp_file}' --upload {user_data}:/root/user-data",
                warn=False, hide=True
            )
            logger.info(result)


            server_images[server_name] = server_image_temp_file

            #virt-customize -a "$image_dir/$image_file" --upload path-to/server/user-data:/root/user-data
            # /etc/hostname
            # /root/.ssh/authorized_keys
            # /root/user-data

        # store the port in statefile and configure ssh config to connect

        # start virt machine? Or should only start if --local was passed to remote task?
        result = c.run(
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
            warn=False, hide=True
        )
        logger.info(result)

    c.state["base_images"] = base_images
    c.state["server_images"] = server_images
