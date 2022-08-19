
output "initial_dev_user_password" {
  value       = random_string.initial_dev_user_password.result
  sensitive   = true
  description = "Initial dev user password. This will require it to be changed on first login."
}

output "host_inventory_ansible_cfg" {
  value = local_file.host_inventory.filename
  description = "The host inventory file that Ansible will use."
}
