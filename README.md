# Chillbox

_Work in Progress_

Infrastructure for websites that use Chill and custom Python Flask services.

## Goals

- Cost efficient by using less resources
- Minimal software is used on the system
- Docker containers are only used on the local host machine
- No remote build pipeline, all builds happen on the local host machine
- Share resources for multiple web sites and their services on a single server
- Use S3 object storage for any static resources; proxied with the NGINX web server
- Applications run on Alpine Linux and don't use systemd

## Non-goals

- Scaling out to multiple servers
- High availability
- Dependency on any specific solutions provided by a single cloud host (vendor
    lock-in)

## Overview

TODO Add chillbox overview graphic

## Quickstart


```bash
./terra.sh
```

## Contributing

Please contact me or create an issue.

## Testing and Development

Tests and shellcheck can be performed via the tests/test.sh shell script. This
uses bats-core for running the shell testing where that works. Most of the
shell scripts are also checked for any issues with shellcheck. An optional
integration test is done at the end of the test which will deploy to
DigitalOcean a temporary Test workspace using Terraform.

```bash
./tests/test.sh
```

## Maintenance

Where possible, an upkeep comment has been added to various parts of the source
code that are known areas that will require updates over time to reduce
software rot. The upkeep comment follows this pattern to make it easier for
commands like grep to find these comments.


```bash
# Search for upkeep comments.
grep --fixed-strings --recursive 'UPKEEP'
```
