# Feature Roadmap



## Implemented Features

This is a list of notable features that have currently been implemented.

- Not coupled to Source Control Management ([SCM]) software. 
    - A site is deployed via a site configuration file.
    - Each site configuration defines a 'release' tar.gz file which contains the
        source code for the site. The release tar.gz file can be referenced
        locally via absolute file path or downloaded from a URL.
    - Deployments will effectively skip already deployed sites based on the
        version string of the site.
- Supported language handlers for services
  - Python 3 WSGI managed by Gunicorn (Planning to support ASGI as well)
  - [Chill] with dynamic or static deployment (Python 3)
  - Immutable services that have their resources stored on S3 object storage
- The build and install of Python service dependencies only use local
    dependencies referenced by a requirements.txt file in the versioned
    artifact. The 
    [pip install --no-index ...](https://github.com/jkenlooper/chillbox/blob/main/src/chillbox/bin/site-init-service-object.sh#L123)
    command is used when installing Python services on the chillbox server for
    better security.
- Each site can use and configure a secure [Redis] instance that is only
    available on a unix socket. Only the site's services can access it. 
- Website services run on [Alpine Linux] and don't use [systemd]
  - [OpenRC] and [s6] is used instead of [systemd] to align with the goal of using less software. Also see [A word about systemd](https://skarnet.org/software/systemd.html) from the author of [s6].
- Shell scripts are [POSIX] compliant
  - Linting via [Shellcheck]
  - Unit tests via [Bats-core] (Bash Automated Testing System)
- A [JSON Schema] has been defined for the site.json files a website uses for configuration.
    - TODO: Publish [src/local/verify-sites/site.schema.json](../src/local/verify-sites/site.schema.json)
- No remote build pipeline, all builds happen on the local host machine
    - Secrets are encrypted and stored securely on the host machine
    - Secrets used on the chillbox server are encrypted to a public key, the
        private key is generated on the chillbox server and never stored
        elsewhere.
- [Terraform] has been isolated inside containers on the local host machine and the state files are encrypted on data volumes
- Deployment to [DigitalOcean] cloud hosting provider
- The user-data script added to the deployed server is encrypted. [Ansible] is
    used to bootstrap the server by decrypting the user-data script and
    executing it as defined in the playbook file. This plaintext user-data script is
    deleted after successfully bootstrapping a server.
- After the chillbox user-data script has been downloaded from the metadata
    service (169.254.169.254/metadata/v1/user-data for DO) the access to
    169.254.169.254 is blocked. This is done as part of the custom [Alpine Linux
    image setup
    script](https://github.com/jkenlooper/alpine-droplet/blob/master/setup.sh#L38).
- [Ansible] is isolated to a container much like Terraform. It is used
    to initialize the chillbox server when first deploying. The [custom Alpine Linux
    image] used for [DigitalOcean] does not include [cloud-init] and I see no
    reason to have it.
- [Ansible] is used to manage the deployed chillbox server with security updates and such.
  - Manually connecting with ssh to the deployed chillbox server is done within the
      ansible container.


## Planned Features

Upcoming list of features that will be implemented.

- All secrets are stored in a tmpfs file system when not encrypted
  - Restarting of the server will require user interaction (via [Ansible]) to decrypt secrets
- Trigger running the update script via ansible playbook

### Other Ideas for New Features

These ideas might be a bit outside of the goals and are not part of any
immediate use case that I currently have. These are the things I would be
tempted to implement.

- Option to use other cloud hosting instead of only [DigitalOcean]
  - [Linode] 
  - [Vultr]
- Deploy multiple chillbox servers for high availability
  - [AWS Route53 failover](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
  - TODO: Find other cloud hosting providers that do this?
- Deploy multiple chillbox servers to different regions and improve response time with [GeoDNS]
- Option to use a managed DNS provider that has [GeoDNS]
  - [AWS Route53 Geo DNS](https://aws.amazon.com/about-aws/whats-new/2014/07/31/amazon-route-53-announces-domain-name-registration-geo-routing-and-lower-pricing/)
  - [Cloudflare Geo steering](https://developers.cloudflare.com/load-balancing/understand-basics/traffic-steering/steering-policies/geo-steering/)
- Support other language handlers for services
  - [Rust]
  - [Deno]
- Start long running worker processes defined by the site. Support using [RQ], [ARQ], or a custom
    run command. Allow running multiple copies of them.
- Batching large jobs by spinning up temporary resources
- Support for running OpenFaaS functions with [faasd](https://docs.openfaas.com/deployment/faasd/)
- Monitoring and ability to easily view logs without being on the server
- Static code analysis done locally as part of the deployment
  - Check for known vulnerabilities (pip-audit, sonarqube, socket.dev, others?)
  - Code quality

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
[Vultr]: https://www.vultr.com/
[Rust]: https://rust-lang.org/
[Go]: https://go.dev/
[Bats-core]: https://github.com/bats-core/bats-core#readme
[shellcheck]: https://www.shellcheck.net/
[GeoDNS]: https://en.wikipedia.org/wiki/GeoDNS
[systemd]: https://systemd.io/
[SCM]: https://en.wikipedia.org/wiki/Version_control
[s6]: https://skarnet.org/software/s6/
[OpenRC]: https://wiki.alpinelinux.org/wiki/OpenRC
[Deno]: https://deno.land/
[cloud-init]: https://cloud-init.io/
[Ansible]: https://docs.ansible.com/
[Shellcheck]: https://github.com/koalaman/shellcheck
[JSON Schema]: https://json-schema.org/
[custom Alpine Linux image]: https://github.com/jkenlooper/alpine-droplet
[Redis]: https://redis.io/
[RQ]: https://python-rq.org/
[ARQ]: https://github.com/samuelcolvin/arq
