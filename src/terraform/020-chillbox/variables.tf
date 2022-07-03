variable "do_token" {
  type        = string
  description = "DigitalOcean access token.  Keep this secure and use best practices when using these."
  sensitive   = true
}
variable "do_spaces_access_key_id" {
  type        = string
  description = "DigitalOcean Spaces access key ID for Terraform to use. Keep this secure and use best practices when using these."
  sensitive   = true
}
variable "do_spaces_secret_access_key" {
  type        = string
  description = "DigitalOcean Spaces secret access key for Terraform to use. Keep this secure and use best practices when using these."
  sensitive   = true
}

variable "do_chillbox_spaces_access_key_id" {
  type        = string
  description = "DigitalOcean Spaces access key ID to use on the chillbox server. Keep this secure and use best practices when using these."
  sensitive   = true
}
variable "do_chillbox_spaces_secret_access_key" {
  type        = string
  description = "DigitalOcean Spaces secret access key to use on the chillbox server. Keep this secure and use best practices when using these."
  sensitive   = true
}

variable "chillbox_gpg_passphrase" {
  type        = string
  description = "GPG key is created on the chillbox server; set the passphrase for it here. Keep this secure and use best practices when using these."
  sensitive   = true
}

variable "tech_email" {
  type        = string
  description = "Contact email address to use for notifying the person in charge of fixing stuff. This is usually the person that can also break all the things. Use your cat's email address here if you have a cat in the house."
}

variable "alpine_custom_image" {
  description = "file name of the built alpine image from jkenlooper/alpine-droplet repo."
  type        = string
}

variable "bucket_region" {
  type        = string
  description = "Bucket region."
  default     = "nyc3"
}
variable "immutable_bucket_name" {
  type        = string
  description = "Immutable bucket name."
}
variable "artifact_bucket_name" {
  type        = string
  description = "Artifact bucket name."
}
variable "s3_endpoint_url" {
  type        = string
  description = "The s3 endpoint URL."
}
variable "sites_manifest" {
  type        = string
  description = "The sites manifest."
  default = "dist/sites.manifest.json"
}


variable "developer_ips" {
  description = "List of ips that will be allowed through the firewall on the SSH port."
  type        = list(string)
}

variable "admin_ips" {
  description = "List of ips that will be allowed access to /chill/site/admin/ routes."
  type        = list(string)
}

variable "web_ips" {
  description = "List of ips that will be allowed through the firewall on port 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}


variable "developer_ssh_key_github" {
  description = "The GitHub usernames that should have access."
  type        = list(string)
}

variable "developer_ssh_key_fingerprints" {
  description = "The fingerprints of any public SSH keys that were added to the DigitalOcean account that should have access to the droplets."
  type        = list(string)
}

variable "chillbox_instance" {
  description = "Used as part of the name in the project as well as in the hostname of any created servers."
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Used as part of the name in the project as well as in the hostname of any created servers."
  type        = string
  default     = "Development"
  validation {
    condition     = can(regex("Development|Test|Acceptance|Production", var.environment))
    error_message = "Must be an environment that has been defined for the project."
  }
}
variable "project_environment" {
  description = "Used to set the environment in the project."
  default     = "Development"
  type        = string
  validation {
    condition     = can(regex("Development|Staging|Production", var.project_environment))
    error_message = "Must be an environment that is acceptable for projects."
  }
}

variable "project_description" {
  type        = string
  default     = "Infrastructure for hosting websites that use Chill."
  description = "Sets the DigitalOcean project description. Should be set to the current version that is being used."
}

variable "project_version" {
  type        = string
  default     = "0"
  description = "Appended to the end of the DigitialOcean project name."
}

variable "chillbox_droplet_size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "region" {
  type    = string
  default = "nyc1"
}

variable "vpc_ip_range" {
  type    = string
  default = "192.168.136.0/24"
}

variable "site_domains" {
  type = list(string)
  description = "List of site domain names that will be pointing to the chillbox ip address."
  default = []
}
variable "domain" {
  default     = "example.com"
  description = "The domain that will be used when creating new DNS records."
  type        = string
  validation {
    condition     = can(regex("[a-zA-Z0-9_][a-zA-Z0-9._-]+[a-zA-Z0-9_]\\.[a-zA-Z0-9]+", var.domain))
    error_message = "The domain must be a valid domain."
  }
}
variable "sub_domain" {
  default     = "chillbox."
  description = "The sub domain name that will be combined with the 'domain' variable to make the FQDN. Should be blank or end with a period."
  type        = string
  validation {
    condition     = can(regex("|[a-zA-Z0-9_][a-zA-Z0-9._-]+[a-zA-Z0-9_]\\.", var.sub_domain))
    error_message = "The sub domain must be blank or be a valid sub domain label. The last character should be a '.' since it will be prepended to the domain variable."
  }
}

variable "dns_ttl" {
  description = "DNS TTL to use for droplets. Minimum is 30 seconds. It is not recommended to use a value higher than 86400 (24 hours)."
  default     = 3600
  type        = number
  validation {
    condition     = can(var.dns_ttl >= 30)
    error_message = "Values for DigitalOcean DNS TTLs must be at least 30 seconds."
  }
}

variable "create_chillbox" {
  default = true
  description = "Create the chillbox droplet."
  type = bool
}
variable "sites_artifact" {
  default = ""
  description = "The sites artifact file."
  type        = string
}
variable "chillbox_artifact" {
  default = ""
  description = "The chillbox artifact file."
  type        = string
}
