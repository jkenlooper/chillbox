# It is not recommended to store any secrets in a private.auto.tfvars file.
# These should only be considered as parameters to use when deploying.

project_description = "Infrastructure for hosting websites that use Chill."

tech_email        = "tech@example.test"

# sub_domain for chillbox server is kept short to avoid going over the 64 char
# limit that letsencrypt ACME server currently has. At least one domain needs to
# be less than 64 characters.
sub_domain = "t.cb."

# Change 'example.test' to a domain that you own
domain = "example.test"
# Only set to true if the 'domain' variable has been set to one that you own.
manage_dns_records = false

# https://eff-certbot.readthedocs.io/en/stable/using.html#changing-the-acme-server
# acme_server is set in acme_server.auto.tfvars.json

# If the terraform-020-chillbox variable 'web_ips' doesn't include "0.0.0.0" the
# letsencrypt ACME server won't be able to perform the http challenge. Set to
# false if this server won't be public and there is no need to use certbot.
# enable_certbot = false

# Chillbox server count. Set to 0 to destroy the server and keep other
# infrastructure that can remain like the custom server image.
# chillbox_count = 0
