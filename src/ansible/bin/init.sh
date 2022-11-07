#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

echo "TODO $script_name: Work in progress notes and commands to run."
cat "$0"
exit 0


doit.sh -s playbook -- playbooks/bootstrap-chillbox-init-credentials.playbook.yml

initial_dev_user_password="$(jq -r '.initial_dev_user_password.value' /run/tmp/ansible/terraform/terraform-010-infra-output.json)"

echo "$initial_dev_user_password"

cat /var/lib/terraform-020-chillbox/host_inventory.ansible.cfg
# TODO create entry in /etc/hosts

ssh -i /run/tmp/ansible/ssh/ansible.pem dev@chillbox-ansibletest-development-0

cat <<'MEOW'
doas su

cat /var/log/chillbox-init/*

ls /etc/chillbox

rm /srv/chillbox/site1/version.txt
/etc/chillbox/bin/update.sh
MEOW
