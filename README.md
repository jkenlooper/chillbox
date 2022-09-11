# Chillbox

[![Keep a Changelog v1.1.0 badge][changelog-badge]][changelog]
[![AGPL-3.0 license][license-badge]][license]

**_Work in Progress_. This is under active development and is not complete.**

Deployment scripts for websites that use [Chill] and custom Python [Flask] services
that are on an [Alpine Linux] server and backed by s3 object storage.
Supports deployments to [DigitalOcean] with [Terraform] and plans to
support other cloud hosting providers like [Linode], and [Vultr].

## Goals

- Infrastructure has **minimal cost**
- Minimize attack surface by using _less_ software
- **Faultless deployments** from a single local machine
- Server maintenance shouldn't be hard
- Document the _why_ more than the _how_

## Overview

**Tech stack is:** [Alpine Linux], [Terraform], [Ansible], container runtime for local development, and [POSIX] compatible shell scripts.

Please see the [Feature Roadmap](./docs/features.md) for a list of implemented and upcoming
features.

`TODO` _Add chillbox overview graphic_
<!-- A bit out of scope, but the diagram generated from using XState could be
shown here. See the experimental branch that is being used to further test this
idea: experiment/statechart -->

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
have their own infrastructure team that manages and maintains that. Chillbox is
not designed ([Out of Scope Features](./docs/features.md#out-of-scope-features))
for that capability on purpose.

**Chillbox is designed for Web Developers that want to develop websites.**

---

## Contributing

Please contact me or create an issue.

## Testing and Development

Tests and [shellcheck] can be performed via the [tests/test.sh](./tests/test.sh) shell script. This
uses [Bats-core] for running the shell testing where that works. Most of the
shell scripts are also checked for any issues with [shellcheck]. An optional
integration test is done at the end of the test which will deploy to
[DigitalOcean] a temporary Test workspace using [Terraform].

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
[Ansible]: https://github.com/ansible/ansible#readme
[NGINX]: https://nginx.org/
[POSIX]: https://en.wikipedia.org/wiki/POSIX
[Linode]: https://www.linode.com/
[Vultr]: https://www.vultr.com/
[Rust]: https://rust-lang.org/
[Go]: https://go.dev/
[Bats-core]: https://github.com/bats-core/bats-core#readme
[shellcheck]: https://www.shellcheck.net/
