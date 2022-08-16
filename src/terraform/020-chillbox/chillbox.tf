resource "random_string" "initial_dev_user_password" {
  length      = 16
  special     = false
  lower       = true
  upper       = true
  number      = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
}

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
  count      = var.chillbox_count
  name       = "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}-${count.index}"
  size       = var.chillbox_droplet_size
  image      = digitalocean_custom_image.alpine.id
  region     = var.region
  vpc_uuid   = digitalocean_vpc.chillbox.id
  ssh_keys   = [for ssh_key in digitalocean_ssh_key.chillbox: ssh_key.id]
  tags       = [digitalocean_tag.fw_web.name, digitalocean_tag.fw_developer_ssh.name, digitalocean_tag.droplet.name]
  monitoring = false
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      image,
      user_data,
      ssh_keys,
    ]
  }
  user_data = one(local_sensitive_file.alpine_box_init[*].content)
}

resource "digitalocean_ssh_key" "chillbox" {
  for_each   = zipmap([for ssh_key in var.developer_public_ssh_keys: md5(ssh_key)], var.developer_public_ssh_keys)
  name       = "Chillbox ${var.chillbox_instance} ${var.environment} ${each.key}"
  public_key = each.value
}

resource "local_sensitive_file" "alpine_box_init" {
  count           = 1
  filename        = "/run/tmp/secrets/terraform-020-chillbox/user_data_chillbox.sh"
  file_permission = "0500"
  content = templatefile("user_data_chillbox.sh.tftpl", {
    tf_developer_public_ssh_keys : "%{for public_ssh_key in var.developer_public_ssh_keys} ${public_ssh_key}\n %{endfor}",
    tf_access_key_id : var.do_chillbox_spaces_access_key_id,
    tf_secret_access_key : var.do_chillbox_spaces_secret_access_key,
    tf_chillbox_gpg_passphrase : var.chillbox_gpg_passphrase,
    tf_dev_user_passphrase : random_string.initial_dev_user_password.result,
    tf_tech_email : var.tech_email,
    tf_immutable_bucket_name : var.immutable_bucket_name,
    tf_immutable_bucket_domain_name : "${var.immutable_bucket_name}.${var.bucket_region}.digitaloceanspaces.com",
    tf_artifact_bucket_name : var.artifact_bucket_name,
    tf_sites_artifact : var.sites_artifact,
    tf_chillbox_artifact : var.chillbox_artifact
    # No slash at the end of this s3_endpoint_url
    tf_s3_endpoint_url : var.s3_endpoint_url,
    tf_chillbox_server_name : "${var.sub_domain}${var.domain}",
  })
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

  name   = regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[0] == "" ? "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}" : "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}.${regex("^(.*?)\\.?([[:alnum:]]+\\.[[:alnum:]]+)$", each.value)[0]}"

  type  = "A"
  value = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl   = var.dns_ttl
}
