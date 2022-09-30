variable "do_token" {
  type        = string
  description = "DigitalOcean access token.  Keep this secure and use best practices when using these."
  sensitive   = true
}
variable "do_spaces_access_key_id" {
  type        = string
  description = "DigitalOcean Spaces access key ID. Keep this secure and use best practices when using these."
  sensitive   = true
}
variable "do_spaces_secret_access_key" {
  type        = string
  description = "DigitalOcean Spaces secret access key. Keep this secure and use best practices when using these."
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

variable "bucket_region" {
  type        = string
  description = "Bucket region."
  default     = "nyc3"
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

variable "developer_public_ssh_keys" {
  description = "The public SSH keys that will be added to the deployed chillbox server."
  type        = list(string)
  nullable    = false
  validation {
    condition     = length(var.developer_public_ssh_keys) != 0
    error_message = "Must have at least one public ssh key in the list."
  }
}

variable "tech_email" {
  type        = string
  description = "Contact email address to use for notifying the person in charge of fixing stuff. This is usually the person that can also break all the things. Use your cat's email address here if you have a cat in the house."
}

variable "sites_artifact" {
  description = "The sites artifact file."
  type        = string
}
variable "chillbox_artifact" {
  description = "The chillbox artifact file."
  type        = string
}
variable "sites_manifest" {
  type        = string
  description = "The sites manifest."
  default     = "dist/sites.manifest.json"
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
