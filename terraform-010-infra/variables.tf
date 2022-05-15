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

variable "chillbox_gpg_passphrase" {
  type        = string
  description = "GPG key is created on the chillbox server; set the passphrase for it here. Keep this secure and use best practices when using these."
  sensitive   = true
}

variable "bucket_region" {
  type        = string
  description = "Bucket region."
  default     = "nyc3"
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
  default     = ""
  description = "Appended to the end of the DigitialOcean project name."
}
