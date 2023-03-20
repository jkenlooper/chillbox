try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

from invoke import task

from chillbox.errors import ChillboxInvalidConfigError

required_keys = set(
    ["instance", "gpg-key", "sqlite-ciphertext-file", "archive-ciphertext-file"]
)

required_commands = set([
    "openssl",
    "python",
    "gpg",
])

optional_commands = set([
    "terraform",
])

@task
def validate_chillbox_config(c):
    with open("example.chillbox.toml", "rb") as f:
        data = tomllib.load(f)
        # pprint(data)

    top_level_keys = set(data.keys())
    if not required_keys.issubset(top_level_keys):
        missing_keys = required_keys.copy()
        missing_keys.difference_update(top_level_keys)
        lines = "\n  ".join(sorted(missing_keys))
        raise ChillboxInvalidConfigError(
            f"INVALID: Missing required keys in the {f.name} file.\nThe following keys are required:\n  {lines}"
        )
    c.run(f"""echo \"The {f.name} file is valid.\"""")


@task(pre=[validate_chillbox_config])
def build(c):
    c.run("echof 'hi'")
