
## Recover from a pulled tfstate file.

./chillbox.sh

On start up these will generate a new gpg key and perform a terraform init.
Enter in the credentials needed like normal.

Should not do a terraform apply yet since the backup tfstate hasn't been pushed.
Just 'exit' after each.

Now the tfstate can be pushed to the containers since the terraform init has
been done.

./chillbox.sh push
