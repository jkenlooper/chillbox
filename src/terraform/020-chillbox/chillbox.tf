resource "digitalocean_spaces_bucket_object" "alpine_custom_image" {
  region = var.bucket_region
  bucket = var.artifact_bucket_name
  key    = "chillbox/${var.alpine_custom_image}"
  acl    = "public-read"
  source = var.alpine_custom_image
}

resource "digitalocean_custom_image" "alpine" {
  name         = "alpine"
  url          = "https://${digitalocean_spaces_bucket_object.alpine_custom_image.bucket}.${digitalocean_spaces_bucket_object.alpine_custom_image.region}.digitaloceanspaces.com/${digitalocean_spaces_bucket_object.alpine_custom_image.key}"
  regions      = [var.region]
  description  = "Alpine custom image"
  distribution = "Unknown"
}

resource "digitalocean_droplet" "chillbox" {
  count         = var.chillbox_count
  name          = "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}"
  size          = var.chillbox_droplet_size
  image         = digitalocean_custom_image.alpine.id
  resize_disk   = false
  region        = var.region
  vpc_uuid      = digitalocean_vpc.chillbox.id
  ssh_keys      = [for ssh_key in digitalocean_ssh_key.chillbox : ssh_key.id]
  tags          = [digitalocean_tag.fw_web.name, digitalocean_tag.fw_developer_ssh.name, digitalocean_tag.droplet.name]
  monitoring    = false
  droplet_agent = false
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      image,
      user_data,
      ssh_keys,
    ]
  }
  user_data = templatefile("init-chillbox.sh.tftpl", {
    tf_dev_user_passphrase_hashed : chomp(file("/var/lib/terraform-010-infra/dev_user_passphrase_hashed")),
    tf_hashed_password_for_ansibledev : chomp(file("/var/lib/terraform-010-infra/chillbox_ansibledev_pass_hashed-${count.index}")),
    tf_bootstrap_chillbox_init_credentials_encrypted : file("/var/lib/terraform-010-infra/bootstrap-chillbox-init-credentials.sh.encrypted"),
  })

  # Create a broken symbolic link in the /var directory to bridge the ansible
  # container to use any sensitive values like ansible_ssh_pass for each host.
  # The ansible container will decrypt the ciphertext with chillbox_local gpg
  # key and create the plaintext file in the /run/tmp/... directory.
  provisioner "local-exec" {
    on_failure = continue
    command    = "mkdir -p /var/lib/terraform-020-chillbox/host_vars"
  }
  provisioner "local-exec" {
    on_failure = continue
    command    = "ln -s /run/tmp/ansible/terraform/${self.name}.json /var/lib/terraform-020-chillbox/host_vars/${self.name}.json"
  }
  provisioner "local-exec" {
    # The ssh_known_hosts file will be updated to include three hostnames for
    # each chillbox server:
    #   - ipv4_address
    #   - chillbox full hostname (chillbox-example-development-0)
    #   - chillbox short hostname (chillbox-0)
    on_failure = fail
    command = <<HERE
    ssh-keyscan -t ed25519 -T 120 ${self.ipv4_address} \
      | sed -nE 's/^(${self.ipv4_address})(.*)$/\1\2\n${self.name}\2\nchillbox-${regex("chillbox-.*-(\\d+)", self.name)[0]}\2/p' \
        > /var/lib/terraform-020-chillbox/ssh_known_hosts-${self.name}
    HERE
  }
  provisioner "local-exec" {
    on_failure = continue
    when       = destroy
    command    = "rm -f /var/lib/terraform-020-chillbox/host_vars/${self.name}.json"
  }
  provisioner "local-exec" {
    on_failure = continue
    when       = destroy
    command    = "rm -f /var/lib/terraform-020-chillbox/ssh_known_hosts-${self.name}"
  }
}

resource "digitalocean_ssh_key" "chillbox" {
  for_each   = zipmap([for ssh_key in var.developer_public_ssh_keys : md5(ssh_key)], var.developer_public_ssh_keys)
  name       = "Chillbox ${var.chillbox_instance} ${var.environment} ${each.key}"
  public_key = each.value
}

resource "digitalocean_record" "chillbox" {
  count  = var.manage_dns_records ? var.chillbox_count : 0
  domain = var.domain
  name   = trimsuffix(var.sub_domain, ".") == "" ? "@" : trimsuffix(var.sub_domain, ".")
  type   = "A"
  value  = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl    = var.dns_ttl
}

resource "digitalocean_record" "site_domains" {
  for_each = var.manage_dns_records ? var.chillbox_count > 0 ? toset(var.site_domains) : [] : []

  # https://regex101.com/r/pgPLQ5/1
  domain = regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[1]
  name   = regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[0] == "" ? "@" : regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[0]

  type  = "A"
  value = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl   = var.dns_ttl
}

resource "digitalocean_record" "hostname_chillbox" {
  count  = var.manage_hostname_dns_records ? var.chillbox_count : 0
  domain = var.domain
  name   = trimsuffix(var.sub_domain, ".") == "" ? "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}" : "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}.${trimsuffix(var.sub_domain, ".")}"
  type   = "A"
  value  = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl    = var.dns_ttl
}

resource "digitalocean_record" "hostname_site_domains" {
  for_each = var.manage_hostname_dns_records ? var.chillbox_count > 0 ? toset(var.site_domains) : [] : []

  # https://regex101.com/r/pgPLQ5/1
  domain = regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[1]

  name = regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[0] == "" ? "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}" : "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}.${regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[0]}"

  type  = "A"
  value = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl   = var.dns_ttl
}

resource "local_sensitive_file" "ansible_host_vars_json" {
  count           = var.chillbox_count
  filename        = "/run/tmp/secrets/terraform-020-chillbox/chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}.json"
  file_permission = "0400"
  content = jsonencode({
    ansible_ssh_pass = var.chillbox_ansibledev_pass[count.index]
    ansible_become_password = var.chillbox_ansibledev_pass[count.index]
  })

  provisioner "local-exec" {
    command    = "rm -f /var/lib/terraform-020-chillbox/host_vars/chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}.json.asc"
    on_failure = continue
  }
  provisioner "local-exec" {
    command    = "mkdir -p /var/lib/terraform-020-chillbox/host_vars/"
    on_failure = continue
  }
  provisioner "local-exec" {
    command    = "gpg --encrypt --recipient '${var.GPG_KEY_NAME}' --armor --output '/var/lib/terraform-020-chillbox/host_vars/chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}.json.asc' --comment 'ansible_ssh_pass for the ansibledev user on chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index} server.' '${self.filename}'"
    on_failure = fail
  }
  provisioner "local-exec" {
    when       = destroy
    command    = "rm -f /var/lib/terraform-020-chillbox/host_vars/chillbox-*-${count.index}.json.asc"
    on_failure = continue
  }
}
