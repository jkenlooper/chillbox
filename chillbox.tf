resource "digitalocean_spaces_bucket_object" "alpine_custom_image" {
  region = digitalocean_spaces_bucket.artifact.region
  bucket = digitalocean_spaces_bucket.artifact.name
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
  count      = 1
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
  user_data = local_file.alpine_box_init.sensitive_content
}

resource "local_file" "alpine_box_init" {
  filename        = "${lower(var.environment)}/alpine-box-init.sh"
  file_permission = "0500"
  sensitive_content = templatefile("alpine-box-init.sh.tftpl", {
    developer_ssh_key_github_list : "%{for username in var.developer_ssh_key_github} ${username} %{endfor}",
    access_key_id : var.access_key_id,
    secret_access_key : var.secret_access_key,
    tech_email : var.tech_email,
    immutable_bucket_name : digitalocean_spaces_bucket.immutable.name,
    artifact_bucket_name : digitalocean_spaces_bucket.artifact.name,
    sites_artifact : data.external.build_artifacts.result.sites_artifact,
    chillbox_artifact : data.external.build_artifacts.result.chillbox_artifact
    # No slash at the end of this s3_endpoint_url
    s3_endpoint_url : "https://${var.bucket_region}.digitaloceanspaces.com",
    chillbox_hostname : "${var.sub_domain}${var.domain}",
  })
}

resource "digitalocean_record" "chillbox" {
  count  = 1
  domain = var.domain
  type   = "A"
  name   = trimsuffix(var.sub_domain, ".")
  value  = one(digitalocean_droplet.chillbox[*].ipv4_address)
  ttl    = var.dns_ttl
}
