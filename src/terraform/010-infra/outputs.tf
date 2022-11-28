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

output "bootstrap_chillbox_pass" {
  value       = random_string.bootstrap_chillbox_pass.result
  sensitive   = true
  description = "The password used to encrypt the bootstrap-chillbox-init-credentials.sh.encrypted file."
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

output "chillbox_ansibledev_pass" {
  value       = random_string.chillbox_ansibledev_pass[*].result
  sensitive   = true
  description = "Passwords for ansibledev user on each chillbox server that is used when automating with Ansible."
}

output "chillbox_count" {
  value       = var.chillbox_count
  description = "Chillbox server count."
}

output "sites_artifact" {
  description = "The sites artifact file."
  value = var.sites_artifact
}
output "chillbox_artifact" {
  description = "The chillbox artifact file."
  value = var.chillbox_artifact
}
