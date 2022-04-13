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
  count      = var.has_chillbox_artifact ? 1 : 0
  name       = lower("chillbox-${var.environment}")
  size       = var.chillbox_droplet_size
  image      = digitalocean_custom_image.alpine.id
  region     = var.region
  vpc_uuid   = digitalocean_vpc.chillbox.id
  ssh_keys   = var.developer_ssh_key_fingerprints
  tags       = [digitalocean_tag.fw_web.name, digitalocean_tag.fw_developer_ssh.name, digitalocean_tag.droplet.name]
  monitoring = false
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      image,
      user_data,
    ]
  }
  user_data = one(local_sensitive_file.alpine_box_init[*].content)
}

resource "local_sensitive_file" "alpine_box_init" {
  count      = var.has_chillbox_artifact ? 1 : 0
  filename        = "${lower(var.environment)}/alpine-box-init.sh"
  file_permission = "0500"
  content = templatefile("alpine-box-init.sh.tftpl", {
    developer_ssh_key_github_list : "%{for username in var.developer_ssh_key_github} ${username} %{endfor}",
    access_key_id : var.do_spaces_access_key_id,
    secret_access_key : var.do_spaces_secret_access_key,
    tech_email : var.tech_email,
    immutable_bucket_name : var.immutable_bucket_name,
    artifact_bucket_name : var.artifact_bucket_name,
    sites_artifact : var.sites_artifact,
    chillbox_artifact : var.chillbox_artifact
    # No slash at the end of this s3_endpoint_url
    s3_endpoint_url : var.s3_endpoint_url,
    chillbox_hostname : "${var.sub_domain}${var.domain}",
    #install_aws_cli_sh : file("${path.root}/bin/install-aws-cli.sh"),
  })
}

resource "digitalocean_record" "chillbox" {
  count      = var.has_chillbox_artifact ? 1 : 0
  domain = var.domain
  type   = "A"
  name   = trimsuffix(var.sub_domain, ".")
  value  = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl    = var.dns_ttl
}
# TODO create all other digitalocean_record resources for each domain listed in
# sites.json. Prepend sub_domain with the environment.
