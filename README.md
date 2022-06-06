# Chillbox

[![Keep a Changelog v1.1.0 badge][changelog-badge]][changelog]
[![AGPL-3.0 license][license-badge]][license]

**_Work in Progress_. This is under active development and is not complete.**

Infrastructure for websites that use [Chill] and custom Python [Flask] services
and are deployed on a single server.

Tech stack is:
- [Alpine Linux] Server (Custom image uploaded to [DigitalOcean])
  - No systemd
  - Small, simple, and secure
- S3 Object Storage ([DigitalOcean Spaces])
  - Stores artifacts used for deployments
  - Stores any persistent data needed by websites
  - Stores secrets as encrypted files
  - Stores the public immutable static resources used by websites (NGINX serves these)
- A Container runtime (on local Linux machine)
    - [Docker Engine](https://docs.docker.com/engine/)
    - [containerd](https://containerd.io/)
    - ...or other compatible ones
- [Chill] for static and dynamic services in a website
- [Flask] for custom Python code needed for website services
- [SQLite] (used by deployed Chill and Flask services)
- [Terraform] for deploying to cloud hosting providers (isolated in a container on local Linux machine)
- [NGINX] web server
- [POSIX] compatible shell scripts

## Goals

This project is designed for a specific use case and is not ideal for all kinds
of website deployments.

- Infrastructure has minimal cost
- Limited number of language handlers for deployed website services
- Minimize attack surface by using less software
- Faultless deployments that don't require multiple steps
- Server maintenance shouldn't be hard
- Document the why more than the how

## Implemented Features

This is a list of notable features that have currently been implemented.

- Supported language handlers for services
  - [Flask] (Python 3)
  - [Chill] with dynamic or static deployment (Python 3)
- Website services run on [Alpine Linux] and don't use systemd
- Shell scripts are POSIX compliant and mostly have unit tests with Bats-Core
- A JSON Schema has been defined for the site.json files a website uses for configuration.
- No remote build pipeline, all builds happen on the local host machine
- Terraform has been isolated inside containers on the local host machine and the state files are encrypted on data volumes
- Deployment to [DigitalOcean] cloud hosting provider


## Planned Features

Upcoming list of features that will be implemented.

- All secrets are stored in a tmpfs file system when not encrypted
  - Restarting of the server will require user interaction (via Ansible) to decrypt secrets
- Trigger running the update script via secured webhook in chillbox server
- Use Ansible to manage the deployed chillbox server with security updates and such

### Other Ideas for New Features

These ideas might be a bit outside of the goals and are not part of any
immediate use case that I currently have. It may be better to adopt a different
solution (kubernetes) if the below features are needed. These are the things I
would be tempted to implement.

- Option to use [Linode] for hosting instead of only [DigitalOcean]
- Deploy multiple chillbox servers for high availability
  - [AWS Route53 failover](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
  - TODO: Find other cloud hosting providers that do this?
- Deploy multiple chillbox servers to different regions and improve response time with [GeoDNS]
- Option to use a managed DNS provider that has [GeoDNS](https://en.wikipedia.org/wiki/GeoDNS)
  - [AWS Route53 Geo DNS](https://aws.amazon.com/about-aws/whats-new/2014/07/31/amazon-route-53-announces-domain-name-registration-geo-routing-and-lower-pricing/)
  - [Cloudflare Geo steering](https://developers.cloudflare.com/load-balancing/understand-basics/traffic-steering/steering-policies/geo-steering/)
- Support other language handlers for services
  - [Rust]
  - [Go] (maybe?)
- Batching large jobs by spinning up temporary resources
- Support for running OpenFaaS functions with [faasd](https://docs.openfaas.com/deployment/faasd/)
- Monitoring and ability to easily view logs without being on the server

## Out of Scope Features

This project may not be a good fit for high traffic sites that can't experience
downtime for updates and maintenance.  A better fit for those kind of
requirements is probably [kubernetes](https://kubernetes.io/),
[Terraform Cloud](https://cloud.hashicorp.com/products/terraform),
[Hashicorp Vault](https://www.hashicorp.com/products/vault), etc..

- Use of cloud hosting provider services that have expensive bandwidth costs (free tiers and such are not considered)
  - AWS CloudFront - 0.085 per 1GB transfer out
  - AWS EC2 and other compute - 0.09 per 1GB?
  - AWS S3 Buckets - 0.09 per 1GB?
- Auto scaling resources
- Using other Linux distributions besides [Alpine Linux]
- Deployments triggered by version control ([GitOps](https://en.wikipedia.org/wiki/GitOps#GitOps))
- Dependency on any specific solutions provided by a single cloud host (vendor
    lock-in)
- Use of containers on the server
- No virtual machines like [Firecracker](https://firecracker-microvm.github.io/)

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
./terra.sh apply
```

## Manual Deployment on [Alpine Linux] Server

Download the bin/chillbox-init.sh script and run it on an existing [Alpine
Linux]
Server version 3.15. It will prompt for any variables that it needs in order to
initialize chillbox.

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
[Linode]: https://www.linode.com/
[Rust]: https://rust-lang.org/
[Go]: https://go.dev/
