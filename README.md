# Chillbox

_Work in Progress_. This is under active development and is not complete.

Infrastructure for websites that use
[Chill](https://github.com/jkenlooper/chill)
and custom Python Flask services.

## Goals

This project is designed for a specific use case and is not ideal for all kinds
of website deployments.  

- Cost efficient by using less resources
- Minimal software is used on the system
- Docker containers are only used on the local host machine
- No remote build pipeline, all builds happen on the local host machine
- Single local host machine is used for building and deploying
- Share resources for multiple web sites and their services on a single server
- Use S3 object storage for any static resources; proxied with the NGINX web server
- Applications run on Alpine Linux and don't use systemd
- No dependency on version control software for deployments

## Non-goals

This project may not be a good fit if you need to scale out, or have needs that
are beyond a single server. A better fit for those kind of requirements is
probably [kubernetes](https://kubernetes.io/),
[Terraform Cloud](https://cloud.hashicorp.com/products/terraform),
[Hashicorp Vault](https://www.hashicorp.com/products/vault), etc..

- Scaling out to multiple servers
- High availability
- Supporting deployment from other local machines
- Using other Linux distributions besides Alpine Linux
- Deployments triggered by version control (git ops)
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
