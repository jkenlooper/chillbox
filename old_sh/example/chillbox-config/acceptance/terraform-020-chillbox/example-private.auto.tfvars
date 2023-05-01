# It is not recommended to store any secrets in a private.auto.tfvars file.
# These should only be considered as parameters to use when deploying.

project_description = "Infrastructure for hosting websites that use Chill."

# Example of other common things to put here:
#
# chillbox_droplet_size = "s-1vcpu-512mb-10gb"
#
# region        = "nyc1"
# bucket_region = "nyc3"
#
# developer_ips = ["1.2.3.4"]
# admin_ips     = ["1.2.3.4"]
#
# Block all outside access by setting the web_ips value.
# This could also include a load balancer IP.
# web_ips = ["1.2.3.4"]
#
# If web_ips doesn't include "0.0.0.0" the letsencrypt ACME server won't be able
# to perform the http challenge. Set 'enable_certbot' variable in terraform-010-infra.
#
# Plan your network https://docs.digitalocean.com/products/networking/vpc/concepts/plan-your-network/
# cidrsubnets("192.168.136.0/24", 4, 4, 4, 4)
# tolist([
#   "192.168.136.0/28",
#   "192.168.136.16/28",
#   "192.168.136.32/28",
#   "192.168.136.48/28",
# ])
vpc_ip_range = "192.168.136.32/28"

# DNS TTL to use for droplets. Minimum is 30 seconds. It is not recommended to
# use a value higher than 86400 (24 hours).
dns_ttl = 300
