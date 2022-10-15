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

output "user_data_password" {
  value       = random_string.user_data_password.result
  sensitive   = true
  description = "The password used to encrypt the user-data."
}

output "tech_email" {
  value       = var.tech_email
  description = "Tech email."
}
output "domain" {
  value       = var.domain
  description = "Domain name."
}
output "sub_domain" {
  value       = var.sub_domain
  description = "Sub domain name."
}
output "initial_dev_user_password" {
  value       = random_string.initial_dev_user_password.result
  sensitive   = true
  description = "Initial dev user password. This will require it to be changed on first login."
}
