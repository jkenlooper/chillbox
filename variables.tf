variable "access_key_id" {
  type        = string
  description = "S3 object storage access key ID. Keep this secure and use best practices when using these.  It is recommended to export an environment variable for this like TF_VAR_access_key_id if you aren't entering it manually each time."
  sensitive   = true
}
variable "secret_access_key" {
  type        = string
  description = "S3 object storage secret access key. Keep this secure and use best practices when using these.  It is recommended to export an environment variable for this like TF_VAR_secret_access_key if you aren't entering it manually each time."
  sensitive   = true
}
variable "app_access_key_id" {
  type        = string
  description = "S3 object storage access key ID for the deployed application to use. These are stored on the server and used by the application to read and write to S3 object storage."
  sensitive   = false
  default     = "only-set-this-on-new-server-creation"
}
variable "app_secret_access_key" {
  type        = string
  description = "S3 object storage secret access key for the deployed application to use. These are stored on the server and used by the application to read and write to S3."
  sensitive   = true
  default     = "only-set-this-on-new-server-creation"
}
variable "s3_endpoint_url" {
  type = string
  sensitive = false
  validation {
    condition = can(regex("https?://[^/]+", var.s3_endpoint_url))
    error_message = "Must be a URL without a slash at the end."
  }
}
variable "tech_email" {
  type        = string
  description = "Contact email address to use for notifying the person in charge of fixing stuff. This is usually the person that can also break all the things. Use your cat's email address here if you have a cat in the house."
}

variable "chillbox_hostname" {
  type = string
  default = "todo.example.com"
}
variable "chillbox_url" {
  type = string
  default = ""
  description = "The chillbox host URL. This will be an empty string if local."
}


variable "chillbox_artifact" {
  description = ""
  type        = string
  validation {
    condition     = can(regex("chillbox.+\\.(tar\\.gz|bundle)", var.chillbox_artifact))
    error_message = "Must be a file that was generated from the `make dist` command. The Development and Test environments will automatically create a git bundle instead."
  }
}

variable "developer_ips" {
  description = "List of ips that will be allowed through the firewall on the SSH port."
  type        = list(string)
  # TODO: add validation for ips
}

variable "admin_ips" {
  description = "List of ips that will be allowed access to /chill/site/admin/ routes."
  type        = list(string)
  # TODO: add validation for ips
}

variable "web_ips" {
  description = "List of ips that will be allowed through the firewall on port 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  # TODO: add validation for ips
}


variable "developer_ssh_key_github" {
  description = "The GitHub usernames that should have access."
  type        = list(string)
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

variable "init_user_data_script" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = "nyc1"
}

variable "vpc_ip_range" {
  type    = string
  default = "192.168.126.0/24"
}

variable "domain" {
  default     = "massive.xyz"
  description = "The domain that will be used when creating new DNS records."
  type        = string
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

