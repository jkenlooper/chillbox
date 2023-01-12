# It is not recommended to store any secrets in a private.auto.tfvars file.
# These should only be considered as parameters to use when deploying.

project_description = "Infrastructure for hosting websites that use Chill."

tech_email        = "tech@example.test"

# Change 'chill.box' to a domain that you own
domain = "chill.box"
sub_domain = "test.example."

# https://eff-certbot.readthedocs.io/en/stable/using.html#changing-the-acme-server
acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
