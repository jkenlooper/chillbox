terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token             = var.do_token
  spaces_access_id  = var.do_spaces_access_key_id
  spaces_secret_key = var.do_spaces_secret_access_key
}

resource "digitalocean_project" "chillbox-infra" {
  name        = "ChillBox Infrastructure - ${var.chillbox_instance} ${var.environment} ${var.project_version}"
  description = var.project_description
  purpose     = "Website Hosting"
  environment = var.project_environment
  resources = compact([
    digitalocean_spaces_bucket.artifact.urn,
    digitalocean_spaces_bucket.immutable.urn,
  ])
}

resource "random_uuid" "immutable" {}
resource "random_uuid" "artifact" {}

resource "digitalocean_spaces_bucket" "artifact" {
  name   = substr("chillbox-artifact-${lower(var.environment)}-${lower(var.chillbox_instance)}-${random_uuid.artifact.result}", 0, 63)
  region = var.bucket_region
  acl    = "private"
}

resource "digitalocean_spaces_bucket" "immutable" {
  name   = substr("chillbox-immutable-${lower(var.environment)}-${lower(var.chillbox_instance)}-${random_uuid.immutable.result}", 0, 63)
  region = var.bucket_region
  acl    = "public-read"
}

# outputs.tf
output "s3_endpoint_url" {
  value       = "https://${digitalocean_spaces_bucket.artifact.region}.digitaloceanspaces.com/"
  description = "The s3 endpoint url for DigitalOcean Spaces set to the region of the artifact bucket."
}
output "immutable_bucket_name" {
  value       = digitalocean_spaces_bucket.immutable.name
  description = "Immutable bucket name is used by the NGINX server when serving a site's static resources."
}
output "artifact_bucket_name" {
  value       = digitalocean_spaces_bucket.artifact.name
  description = "Artifact bucket name is used to store artifact files."
}
