# Chillbox

[![Keep a Changelog v1.1.0 badge][changelog-badge]][changelog]
[![AGPL-3.0 license][license-badge]][license]

**_Work in Progress_. This is under active development and is not complete.**

Deployment scripts for websites that use [Chill] and Python services
that are on an [Alpine Linux] server and backed by S3 object storage.

## Goals

- Infrastructure has **minimal cost**
- Minimize attack surface by using _less_ software
- **Faultless deployments** from a local machine are secure
- Server maintenance shouldn't be hard
- Well written documentation

## Overview

**Tech stack is:** [Alpine Linux], [Python], and [POSIX] compatible shell scripts.

Chillbox was initially implemented as a very opinionated solution to provision
and maintain a [DigitalOcean] droplet server and surrounding infrastructure.
That initial solution is on this other git branch:
[initial-shell-implementation](https://github.com/jkenlooper/chillbox/tree/initial-shell-implementation).
It was restructured since then to not focus on provisioning infrastructure with
[Terraform] and [DigitalOcean]. It is now split into two separate pieces;
a Python package ([chillbox]) and shell scripts ([chillbox-server]). The
chillbox-server scripts are mostly specific for running on an [Alpine Linux]
server and are designed around the original website deployment configured by
JSON files. The [chillbox] Python command _can_ be used with [chillbox-server]
files, or could be used with a custom set of files to deploy and maintain
servers with different Linux distributions.

### *Outdated Information* 

**TODO:** Update feature roadmap and overview graphic with the new implementation.

See the [Feature Roadmap](./chillbox-server/docs/features.md) for a list
of implemented and upcoming features.

[Chillbox Overview Flowchart](./chillbox-server/docs/diagrams/overview.mmd)

### Why?

Hosting a website is becoming more and more complex. Complexity can come
with a cost in a number of areas and some of those are not easily simplified.
A Web Developer that needs to create and maintain a website should always be
able to do that on their local machine and also deploy it to a server they
manage. The tools needed to do that should be understood and simple enough to
maintain. The complicated bits with their website should be their actual custom
website code, not the infrastructure that it requires.

The goals of keeping things simple and free from vendor lock-in are important
because it is more maintainable this way in the long run.  Not every website
needs to be able to scale out automatically when it gets a traffic spike. Having
that capability comes with a high cost. A server can handle a lot of traffic
(depending on the custom website code) and can be scaled up and down manually as
needed. A company that does need to automatically scale out would probably also
have their own infrastructure team that manages and maintains that.

**Chillbox is designed for Web Developers that want to develop websites.**

---

## Contributing

Please contact me or create an issue.

## Testing and Development

Checkout the project source code at [https://github.com/jkenlooper/chillbox]()
which includes all the files and further documentation.

## Maintenance

Where possible, an upkeep comment has been added to various parts of the source
code. These are known areas that will require updates over time to reduce
software rot. The upkeep comment follows this pattern to make it easier for
commands like grep to find these comments.

Example UPKEEP comment has at least a 'due:' or 'label:' or 'interval:' value
surrounded by double quotes (").
````
Example-> # UPKEEP due: "2022-12-14" label: "hashicorp/terraform base image" interval: "+4 months"
````

The grep command to find all upkeep comments with their line numbers.
```bash
# Search for UPKEEP comments.
grep -r -n -E "^\W+UPKEEP\W+(due:\W?\".*?\"|label:\W?\".*?\"|interval:\W?\".*?\")" .

# Or
docker run --rm \
  --mount "type=bind,src=$PWD,dst=/tmp/upkeep,readonly=true" \
  --workdir=/tmp/upkeep \
  alpine \
  grep -r -n -E "^\W+UPKEEP\W+(due:\W?\".*?\"|label:\W?\".*?\"|interval:\W?\".*?\")" .

# Or show only past due UPKEEP comments.
make upkeep
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
[Ansible]: https://github.com/ansible/ansible#readme
[NGINX]: https://nginx.org/
[POSIX]: https://en.wikipedia.org/wiki/POSIX
[Linode]: https://www.linode.com/
[Vultr]: https://www.vultr.com/
[Rust]: https://rust-lang.org/
[Go]: https://go.dev/
[Bats-core]: https://github.com/bats-core/bats-core#readme
[shellcheck]: https://www.shellcheck.net/
[Python]: https://www.python.org/
[chillbox]: https://pypi.org/project/chillbox/
[chillbox-server]: https://github.com/jkenlooper/chillbox/tree/main/chillbox-server
