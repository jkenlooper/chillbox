# Chillbox

[![Keep a Changelog v1.1.0 badge][changelog-badge]][changelog]
[![AGPL-3.0 license][license-badge]][license]

**_Work in Progress_. This is under active development and is not complete.**

Infrastructure for websites that use [Chill] and custom Python Flask services
and are deployed on a single server.

Tech stack is:
- [Alpine Linux] Server (Custom image uploaded to [DigitalOcean])
- S3 Object Storage ([DigitalOcean Spaces])
- A Container runtime (on local Linux machine)
    - [Docker Engine](https://docs.docker.com/engine/)
    - [containerd](https://containerd.io/)
    - ...or other compatible ones
- [Chill]
- [Flask]
- [SQLite] (used by deployed Chill and Flask services)
- [Terraform] (isolated in a container on local Linux machine)
- [NGINX] web server
- [POSIX] compatible shell scripts


## Goals

This project is designed for a specific use case and is not ideal for all kinds
of website deployments.

- Cost efficient by using less resources
- Minimal software is used on the system
- Docker containers are only used on the local host machine
- No remote build pipeline, all builds happen on the local host machine
- Share resources for multiple web sites and their services on a single server
- Use S3 object storage for any static resources; proxied with the NGINX web server
- Applications run on [Alpine Linux] and don't use systemd
- No dependency on version control software for deployments
- Shell scripts are POSIX compliant
- Deployed services are stateless; any persistent storage is kept elsewhere (s3
    object storage, database not on chillbox server)

## Features

...


## Planned Features

...

## Out of Scope Features

This project may not be a good fit if you need to scale out, or have needs that
are beyond a single server. A better fit for those kind of requirements is
probably [kubernetes](https://kubernetes.io/),
[Terraform Cloud](https://cloud.hashicorp.com/products/terraform),
[Hashicorp Vault](https://www.hashicorp.com/products/vault), etc..

- Scaling out to multiple servers
- High availability
- Supporting deployment from other local machines
- Using other Linux distributions besides [Alpine Linux]
- Deployments triggered by version control (git ops)
- Dependency on any specific solutions provided by a single cloud host (vendor
    lock-in)

## Overview

TODO Add chillbox overview graphic

## Quickstart Deployment to [DigitalOcean] with [Terraform]

Dependencies:

* docker container runtime that support tmpfs (Linux only)
* jq
* make
* tar
* shred
* A [DigitalOcean] account

```bash
./terra.sh
```

## Manual Deployment on [Alpine Linux] Server

Download the bin/chillbox-init.sh script and run it on an existing [Alpine
Linux]
Server version 3.15. It will prompt for any variables that it needs in order to
deploy.

```bash
./bin/chillbox-init.sh
```

## Contributing

Please contact me or create an issue.

## Testing and Development

Tests and shellcheck can be performed via the tests/test.sh shell script. This
uses bats-core for running the shell testing where that works. Most of the
shell scripts are also checked for any issues with shellcheck. An optional
integration test is done at the end of the test which will deploy to
[DigitalOcean] a temporary Test workspace using [Terraform].

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
find . \( -name '*.sh' -o -name '*Dockerfile' \) -exec \
grep --line-number --fixed-strings 'UPKEEP' '{}' +
```


[changelog]: ./CHANGELOG.md
[changelog-badge]: https://img.shields.io/badge/changelog-Keep%20a%20Changelog%20v1.1.0-%23E05735
[license]: ./LICENSE
[license-badge]: https://img.shields.io/badge/license-AGPL%20V3-blue
[Alpine Linux]: https://alpinelinux.org/
[DigitalOcean]: https://www.digitalocean.com/
[DigitalOcean Spaces]: https://www.digitalocean.com/products/spaces
[Chill]: https://github.com/jkenlooper/chill
[Flask]: https://flask.palletsprojects.com/en/2.1.x/
[SQLite]: https://sqlite.org/index.html
[Terraform]: https://www.terraform.io/
[NGINX]: https://nginx.org/
[POSIX]: https://en.wikipedia.org/wiki/POSIX
