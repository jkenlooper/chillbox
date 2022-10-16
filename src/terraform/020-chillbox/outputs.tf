
output "initial_dev_user_password" {
  value       = var.initial_dev_user_password
  sensitive   = true
  description = "Initial dev user password. This will require it to be changed on first login."
}

output "bootstrap_chillbox_pass" {
  value       = var.bootstrap_chillbox_pass
  sensitive   = true
  description = "The password used to encrypt the user-data."
}
output "host_inventory_ansible_cfg" {
  value = local_file.host_inventory.filename
  description = "The host inventory file that Ansible will use."
}
