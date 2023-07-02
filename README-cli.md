# Chillbox CLI

Secure and render the local files needed to work with and upload to multiple
servers.

The [Chillbox] project is still a _work in progress_ at this time, but this
[chillbox CLI] tool is mostly stable at this point. See parent project
[Chillbox] readme document for more.

## Install

Chillbox CLI can be installed with pip:

```bash
pip install chillbox
```

It also depends on some other commands to be available on the local machine. The
required commands are listed in [commands-info.toml].

## Usage

The chillbox CLI is built around the [Invoke] and [Fabric] packages. The
built-in '--help' option can be used. There are number of subcommands available
that each have their own help docstring.

```bash
# Show the general help and available subcommands.
chillbox --help

# Show the help for the 'init' subcommand.
chillbox --help init
```

A configuration file is necessary to do anything with the chillbox CLI. It will
default to use the `chillbox.toml` file in the current working directory. See
the [docs/configuration-file.md] for more information about the chillbox
configuration file.

### Dependencies

Running a chillbox subcommand will automatically check for any other required
commands and show which were not found. The whole list of these are listed in
the [commands-info.toml] file. Any missing commands that are required will cause
an error to be shown when running a chillbox subcommand.

## Documentation

See further documentation for Chillbox at [docs/README.md]

## Contributing

Please contact me or create an issue.

Any submitted changes to this project require the commits to be signed off with
the [git command option
'--signoff'](https://git-scm.com/docs/git-commit#Documentation/git-commit.txt---signoff).
This ensures that the committer has the rights to submit the changes under the
project's license and agrees to the [Developer Certificate of
Origin](https://developercertificate.org).


[Chillbox]: https://github.com/jkenlooper/chillbox#readme
[chillbox CLI]: https://pypi.org/project/chillbox/
[commands-info.toml]: https://github.com/jkenlooper/chillbox/blob/main/src/chillbox/data/commands-info.toml
[docs/configuration-file.md]: https://github.com/jkenlooper/chillbox/blob/main/docs/configuration-file.md
[docs/README.md]: https://github.com/jkenlooper/chillbox/blob/main/docs/README.md
[Invoke]: https://www.pyinvoke.org/
[Fabric]: https://www.fabfile.org/
