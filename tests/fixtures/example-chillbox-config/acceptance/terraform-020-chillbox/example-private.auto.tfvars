# It is not recommended to store any secrets in a private.auto.tfvars file.
# These should only be considered as parameters to use when deploying.

tech_email        = "tech@example.test"

domain = "example.test"
sub_domain = "acceptance."

# Example of other common things to put here:

# developer_ssh_key_github = [
#   "your-github-username"
# ]
#
# Change to actual ssh key fingerprint
# developer_ssh_key_fingerprints = [
#   "01:23:45:56:78:9a:bc:de:f0:12:34:56:78:89:00:00"
# ]
#
# region        = "nyc1"
# bucket_region = "nyc3"
#
# developer_ips = ["1.2.3.4"]
# admin_ips     = ["1.2.3.4"]
