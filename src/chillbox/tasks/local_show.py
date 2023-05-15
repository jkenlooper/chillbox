import tempfile
import json
from pathlib import Path
from tempfile import mkstemp, mkdtemp

from invoke import task

from chillbox.tasks.local_archive import init
from chillbox.state import ChillboxState
from chillbox.utils import (
    logger,
    remove_temp_files,
    get_template,
    decrypt_file,
)
from chillbox.errors import ChillboxHTTPError
from chillbox.ssh import generate_ssh_config_temp, cleanup_ssh_config_temp
from chillbox.errors import (
    ChillboxArchiveDirectoryError,
    ChillboxMissingFileError,
    ChillboxShowFileError,
)


@task(pre=[init])
def show(c, path_id, sensitive=False):
    """
    Show a path by 'id' from the chillbox archive path directory.

    The path file will be decrypted and unzipped at a temporary directory that
    is returned. This should mainly be used for previewing the rendered contents
    of files before uploading them to a server.

    It is up to the user to delete the temporary directory. The temporary
    directory may contain sensitive values that are normally encrypted when
    stored in the chillbox archive directory.
    """

    instance = c.chillbox_config["instance"]
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state = ChillboxState(archive_directory)
    local_path_list = c.chillbox_config.get("path", [])
    logger.debug(local_path_list)

    public_asymmetric_key = archive_directory.joinpath(
        "local-chillbox-asymmetric", f"{instance}.public.pem"
    )

    secure_temp_file = Path(mkstemp(text=True)[1])
    local_ciphertext_file = archive_directory.joinpath("path", path_id)

    if not local_ciphertext_file.exists():
        raise ChillboxMissingFileError(
            f"ERROR: No file at {local_ciphertext_file}"
        )

    path_mapping = dict(map(lambda x: (x["id"], x), c.chillbox_config.get("path", [])))
    path = path_mapping.get(path_id)
    if not path:
        raise ChillboxArchiveDirectoryError(f"ERROR: No path with id '{path_id}'")
    logger.debug(f"{path.get('owner')} == {state.current_user}")
    if path.get("owner") and (path.get("owner") != state.current_user):
        raise ChillboxShowFileError(
            f"Can't show path '{path_id}' because it is not owned by '{state.current_user}'."
        )
    if path.get("sensitive"):
        if sensitive:
            logger.warning(f"Saving sensitive content to a temporary directory. Be sure to properly remove files afterwards.")
        else:
            raise ChillboxShowFileError(
                f"Can't show path '{path_id}' because it is marked as sensitive and the '--include-sensitve' option was not used."
            )


    tmp_output_dir = Path(mkdtemp())
    tmp_plaintext_file = mkstemp()[1]
    decrypt_file(c, tmp_plaintext_file, local_ciphertext_file)

    target_path = tmp_output_dir.joinpath(Path(path['dest']).name)
    if Path(path["src"]).is_dir():
        target_dir = target_path.resolve(strict=False)
        c.run(f"mkdir -p {target_dir}")
        c.run(
            f"tar x -z -f {tmp_plaintext_file} -C {target_dir} --strip-components 1"
        )
    else:
        c.run(f"gunzip -c -f {tmp_plaintext_file} > {target_path}")

    print(tmp_output_dir)
