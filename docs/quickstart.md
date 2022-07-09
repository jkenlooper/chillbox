
## Quickstart Deployment to [DigitalOcean] with [Terraform]

Dependencies:

* docker container runtime that support tmpfs (Linux only)
* jq
* make
* tar
* shred
* A [DigitalOcean] account

```bash
./chillbox.sh apply

## TODO
make
# Install the 'chillbox' command
make install

# Set to development, test, acceptance, or production
export WORKSPACE=development
# Create a new instance and enter the details in the prompt
./chillbox.sh name_of_instance init
# Apply the changes and deploy the chillbox instance with Terraform
./chillbox.sh name_of_instance apply
```

[DigitalOcean]: https://www.digitalocean.com/
[Terraform]: https://www.terraform.io/
