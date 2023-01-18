# It is not recommended to store any secrets in a private.auto.tfvars file.
# These should only be considered as parameters to use when deploying.

project_description = "Infrastructure for hosting websites that use Chill."

tech_email        = "tech@example.test"

# Change 'chill.box' to a domain that you own
domain = "chill.box"
sub_domain = "test.example."

# https://eff-certbot.readthedocs.io/en/stable/using.html#changing-the-acme-server
# acme_server is set in acme_server.auto.tfvars.json

# If the terraform-020-chillbox variable 'web_ips' doesn't include "0.0.0.0" the
# letsencrypt ACME server won't be able to perform the http challenge. Set to
# false if this server won't be public and there is no need to use certbot.
# enable_certbot = false

# Chillbox server count. Set to 0 to destroy the server and keep other
# infrastructure that can remain like the custom server image.
# chillbox_count = 0
