# Feature Roadmap



## Implemented Features

This is a list of notable features that have currently been implemented.

- Supported language handlers for services
  - [Flask] (Python 3)
  - [Chill] with dynamic or static deployment (Python 3)
- Website services run on [Alpine Linux] and don't use [systemd]
- Shell scripts are [POSIX] compliant and mostly have unit tests with [Bats-core] (Bash Automated Testing System)
- A JSON Schema has been defined for the site.json files a website uses for configuration.
- No remote build pipeline, all builds happen on the local host machine
- [Terraform] has been isolated inside containers on the local host machine and the state files are encrypted on data volumes
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
