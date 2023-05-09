# Chillbox CLI

Secure and render the local files needed to work with and upload to multiple servers.

The [Chillbox] project is still a _work in progress_ at this time, but this
[chillbox] CLI tool is mostly stable at this point. See parent project
[Chillbox] readme document for more.

## Install

Chillbox can be installed with pip:

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

### Dependencies

Running a chillbox subcommand will automatically check for any other required
commands and show which were not found. The whole list of these are listed in
the [commands-info.toml] file. Any missing commands that are required will cause
an error to be shown when running a chillbox subcommand.

[Chillbox]: https://github.com/jkenlooper/chillbox#readme
[chillbox]: https://pypi.org/project/chillbox/
[commands-info.toml]: https://github.com/jkenlooper/chillbox/blob/main/src/chillbox/data/commands-info.toml
[Invoke]: https://www.pyinvoke.org/
[Fabric]: https://www.fabfile.org/
