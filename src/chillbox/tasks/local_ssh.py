import tempfile
import json
from pathlib import Path

from invoke import task
import httpx

from chillbox.tasks.local_archive import init
from chillbox.utils import (
    logger,
    remove_temp_files,
    get_template,
)
from chillbox.errors import ChillboxHTTPError


@task(pre=[init])
def ssh_unlock(c):
    """
    Create a temporary ssh_config file and identity file that can be used for ssh commands.

    The temporary ssh_config file will be automatically created based on
    information found in the chillbox configuration. The identity file is the
    private ssh key if one was created specifically for the user.
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    user_known_hosts_file = archive_directory.joinpath("ssh_known_hosts").resolve()

    ssh_config = c.state.get("ssh_config_temp")
    identity_file = c.state.get("identity_file_temp")
    current_user = c.state["current_user"]

    def user_has_access(server):
        "The current user has access to a server if they are the owner or in the list of login-users."
        if server.get("owner") and server.get("owner") == current_user:
            return True
        login_users = server.get("login-users", [])
        return any(map(lambda x: x.startswith(current_user), login_users))

    user_server_list = list(filter(user_has_access, c.chillbox_config.get("server", [])))

    # Always delete any older ssh_config first. The identity_file_temp was
    # created in user_ssh_init as part of init process and should not be removed
    # here.
    remove_temp_files(paths=[ssh_config])

    ssh_config = tempfile.mkstemp(suffix=".chillbox.ssh_config")[1]
    c.state["ssh_config_temp"] = ssh_config
    logger.debug(f"{ssh_config=}")

    template = get_template("ssh_config.jinja")
    with open(ssh_config, "w") as f:
        f.write(template.render({
            "ssh_config": ssh_config,
            "current_user": c.state["current_user"],
            "known_hosts_file": user_known_hosts_file,
            "identity_file": identity_file,
            "user_server_list": user_server_list,
        }))

    logger.info(
        f"Generated a ssh_config file to use with ssh when connecting to a chillbox server. Replace CHILLBOX_SERVER_HOSTNAME with hostname of the server.\n  Use the ssh command:\n  ssh -F {ssh_config} CHILLBOX_SERVER_HOSTNAME"
    )
    print(ssh_config)


@task(pre=[init])
def ssh_lock(c):
    """
    Remove temporary ssh_config file and identity file that was created for ssh commands.
    """
    archive_directory = Path(c.chillbox_config["archive-directory"])
    ssh_config = c.state.get("ssh_config_temp")
    identity_file = c.state.get("identity_file_temp")

    # Always delete any older ones first
    remove_temp_files(paths=[ssh_config, identity_file])

    del c.state["ssh_config_temp"]
    del c.state["identity_file_temp"]


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
        r = httpx.get(
            github_api_list_public_keys_for_user,
            follow_redirects=True,
            headers={
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        r.raise_for_status()
    except httpx.HTTPError as err:
        raise ChillboxHTTPError(f"ERROR: Request failed. {err}")
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
