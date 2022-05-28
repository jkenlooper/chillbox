
output "initial_dev_user_password" {
  value       = random_string.initial_dev_user_password.result
  sensitive   = true
  description = "Initial dev user password. Thi will require it to be changed on first login."
}
