import tempfile
import json
from pathlib import Path

from invoke import task
import httpx

from chillbox.tasks.local_archive import init
from chillbox.utils import logger, get_state_file_data, save_state_file_data
from chillbox.errors import ChillboxHTTPError


def remove_temp_ssh_files(ssh_config, identity_file):
    if ssh_config and Path(ssh_config).exists():
        Path(ssh_config).unlink()
    if identity_file and Path(identity_file).exists():
        Path(identity_file).unlink()


@task(pre=[init])
def ssh_unlock(c):
    """
    Create a temporary ssh_config file and identity file that can be used for ssh commands.

    The temporary ssh_config file will be automatically created based on
    information found in the chillbox configuration. The identity file is the
    private ssh key if one was created specifically for the user.

    ## Example ssh_config file contents.
    ```
    StrictHostKeyChecking yes
    # For each server in the chillbox configuration, a Host block is created.
    Host {ipv4_address} {hostname}
      IdentityFile $TEMPDIR/temporary-path-to/chillbox.pem
      Hostname {hostname}
      # The owner is the same as the owner of the chillbox archive directory.
      User {owner}
    ```
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state_file_data = get_state_file_data(archive_directory)

    ssh_config = state_file_data.get("ssh_config_temp")
    identity_file = state_file_data.get("identity_file_temp")

    # Always delete any older ones first
    remove_temp_ssh_files(ssh_config, identity_file)

    ssh_config = tempfile.mkstemp(suffix=".chillbox.ssh_config")[1]
    state_file_data["ssh_config_temp"] = ssh_config
    logger.debug(f"{ssh_config=}")
    identity_file = tempfile.mkstemp(suffix=".chillbox.pem")[1]
    state_file_data["identity_file_temp"] = identity_file
    logger.debug(f"{identity_file=}")

    with open(ssh_config, "w") as f:
        f.write(
            """# TODO create ssh_config same way as src/terraform/020-chillbox/ansible_ssh_config.tftpl"""
        )

    with open(identity_file, "w") as f:
        f.write("""# TODO output the private ssh key that was generated here.""")

    logger.info(
        f"Generated a ssh_config file to use with ssh when connecting to a chillbox server. Replace CHILLBOX_SERVER_HOSTNAME with hostname of the server.\n  Use the ssh command:\n  ssh -F {ssh_config=} CHILLBOX_SERVER_HOSTNAME"
    )
    print(ssh_config)

    save_state_file_data(archive_directory, state_file_data)


@task(pre=[init])
def ssh_lock(c):
    """
    Remove temporary ssh_config file and identity file that was created for ssh commands.
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    state_file_data = get_state_file_data(archive_directory)
    ssh_config = state_file_data.get("ssh_config_temp")
    identity_file = state_file_data.get("identity_file_temp")

    # Always delete any older ones first
    remove_temp_ssh_files(ssh_config, identity_file)

    del state_file_data["ssh_config_temp"]
    del state_file_data["identity_file_temp"]
    save_state_file_data(archive_directory, state_file_data)


@task
def fetch_github_public_ssh_key(c, user):
    """
    Show the public ssh keys for a GitHub user.

    The output of this can be used to manually add the public ssh key to the
    chillbox configuration file (chillbox.toml).

    Basically does this shell script, but uses Python to make it more portable.
    ```bash
    GITHUB_USER="set-to-github-user"
    curl "https://api.github.com/users/$GITHUB_USER/keys" \\
      --silent -L \\
      -H "Accept: application/vnd.github+json" \\
      -H "X-GitHub-Api-Version: 2022-11-28" \\
        | jq -r '.[] | .key'
    ```
    """
    # UPKEEP due: "2024-03-28" label: "GitHub API public ssh keys" interval: "+1 year"
    # https://docs.github.com/en/rest/users/keys?apiVersion=2022-11-28#list-public-keys-for-a-user

    github_api_list_public_keys_for_user = f"https://api.github.com/users/{user}/keys"
    try:
        r = httpx.get(github_api_list_public_keys_for_user,
                      follow_redirects=True,
                      headers={
          "Accept": "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28"
        })
        r.raise_for_status()
    except httpx.HTTPError as err:
        raise ChillboxHTTPError(
            f"ERROR: Request failed. {err}"
        )
    logger.debug(r)
    logger.debug(r.url)
    logger.debug(r.reason_phrase)
    logger.debug(r.headers)
    logger.debug(r.elapsed)
    logger.info(f"Successful response from {github_api_list_public_keys_for_user}")
    keys = r.json()
    logger.debug(f"{keys=}")

    remaining = int(r.headers.get("x-ratelimit-remaining", 0))
    remaining_msg = f"GitHub rate limit remaining is {remaining}"
    if remaining < 5:
        logger.warning(remaining_msg)
    else:
        logger.info(remaining_msg)

    if keys and isinstance(keys, list):
        print("\n".join(map(lambda x: x["key"], keys)))
    else:
        logger.warning(f"No public ssh keys found for GitHub user: {user}")
