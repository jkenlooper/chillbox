
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
  value       = local_file.host_inventory.filename
  description = "The host inventory file that Ansible will use."
}
output "ansible_etc_hosts_snippet" {
  value       = local_file.ansible_etc_hosts_snippet.filename
  description = "The snippet that will be appended to the /etc/hosts file inside the ansible container."
}
output "ansible_ssh_config" {
  value       = local_file.ansible_ssh_config.filename
  description = "The ssh_config file that will be used inside the ansible container."
}
