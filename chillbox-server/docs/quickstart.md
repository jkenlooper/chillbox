**_Work in Progress_. Documentation is outdated since the original
implementation.**

## Quickstart Deployment to [DigitalOcean] with [Terraform]

Dependencies:

* docker container runtime that support tmpfs (Linux only)
* jq
* make
* tar
* shred
* A [DigitalOcean] account

```bash
./chillbox-server/build/update-dep.sh
chillbox init
set -a; . "$(chillbox output-env -s)"; set +a
./chillbox-server/build-sites-artifact.sh
# update the chillbox.toml and set SITE_ARTIFACT env var.
chillbox server-init
ssh -F "$(chillbox ssh-unlock)" alice@local
chillbox -v upload
ssh -F "$(chillbox ssh-unlock)" alice@local
doas su
. /etc/profile.d/chillbox-env.sh
. /etc/profile.d/chillbox-config.sh
/etc/chillbox/bin/chillbox-init.sh

## TODO
make
# Install the 'chillbox' command
make install

# Set to development, test, acceptance, or production
export WORKSPACE=development
# Create a new instance and enter the details in the prompt
chillbox.sh -i name_of_instance init
# Apply the changes and deploy the chillbox instance with Terraform
chillbox.sh -i name_of_instance apply
```

[DigitalOcean]: https://www.digitalocean.com/
[Terraform]: https://www.terraform.io/
