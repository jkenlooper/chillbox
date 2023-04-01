# Ansible with Chillbox

Ansible is an automation tool that is used to maintain the chillbox server.
See the [Ansible documentation] for further information on this tool.

## Connecting with ssh

The local ansible container has been configured to connect with a deployed
chillbox server with ssh securely. Use ssh to manually check on logs and
services when troubleshooting. The 'doit.sh' script handles decrypting the
ssh pem file to a tmpfs mount which is configured to be used when connecting
with ssh.

```sh
# Use the init.sh command to show the initial dev user password.
init.sh

# Show more help for doit.sh script with 'doit.sh -h'.
doit.sh
ssh chillbox-0
```

After using the 'ssh chillbox-0' command to ssh into the chillbox server you may
want to run the following commands:

```sh
# Use doas to switch to the root user.
doas su

# Check the log file for the initial bootstrap script output.
cat /var/log/chillbox-init/*

ls /etc/chillbox

# Manually trigger an update of the sites.
rm /srv/chillbox/site1/version.txt
/etc/chillbox/bin/update.sh
```

TODO: Still have issues with not being able to stop running services when
running the update.sh script. Use the 'kill' command as a workaround.

## Ansible Playbooks

Use ansible commands when running automated tasks like server maintenance and
such. The doit.sh command should be run first if it hasn't been already for the
session.

Cheatsheet:

```sh
# Useful commands to use when developing playbooks.
ansible-playbook playbooks/*.playbook.yml --syntax-check
ansible-lint playbooks/*.playbook.yml 

# Example of running a playbook.
doit.sh -s playbook -- playbooks/bootstrap-chillbox-init-credentials.playbook.yml
```

---

A list of other things that Ansible playbooks might be a good use for.

- ...

[Ansible documentation]: https://docs.ansible.com/
