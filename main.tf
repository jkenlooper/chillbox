terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "digitalocean_project" "chillbox" {
  name        = "ChillBox - ${var.environment} ${var.project_version}"
  description = var.project_version
  purpose     = "Website Hosting"
  environment = var.project_environment
  resources = compact([
    digitalocean_spaces_bucket.artifact.urn,
    digitalocean_spaces_bucket.immutable.urn,
    one(digitalocean_droplet.chillbox[*].urn),
  ])
}

resource "digitalocean_vpc" "chillbox" {
  name        = "chillbox-${lower(var.environment)}"
  description = "ChillBox network for the ${var.environment} environment"
  region      = var.region
  ip_range    = var.vpc_ip_range
}

resource "digitalocean_tag" "fw_developer_ssh" {
  name = "fw_chillbox_${lower(var.environment)}_developer_ssh"
}

resource "digitalocean_tag" "fw_web" {
  name = "fw_chillbox_${lower(var.environment)}_web"
}

resource "digitalocean_tag" "droplet" {
  name = "chillbox_${lower(var.environment)}_droplet"
}

resource "digitalocean_firewall" "developer_ssh" {
  name = "chillbox-${lower(var.environment)}-developer-ssh"
  tags = [digitalocean_tag.fw_developer_ssh.name]
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.developer_ips
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "22"
    destination_addresses = var.developer_ips
  }
}

resource "digitalocean_firewall" "web" {
  name = "chillbox-${lower(var.environment)}-web"
  tags = [digitalocean_tag.fw_web.name]
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = concat(var.web_ips, var.developer_ips, var.admin_ips)
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = concat(var.web_ips, var.developer_ips, var.admin_ips)
  }
  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

data "external" "build_artifacts" {
  program = ["./build-artifacts.sh"]
  query = {
    sites_git_repo = var.sites_git_repo
    sites_git_branch = var.sites_git_branch
    immutable_bucket_name = digitalocean_spaces_bucket.immutable.name
    artifact_bucket_name  = digitalocean_spaces_bucket.artifact.name
    endpoint_url          = "https://${digitalocean_spaces_bucket.artifact.region}.digitaloceanspaces.com/"
    chillbox_url          = "https://${var.sub_domain}${var.domain}"
  }
}

resource "random_uuid" "immutable" {}
resource "random_uuid" "artifact" {}

resource "digitalocean_spaces_bucket" "artifact" {
  name   = substr("chillbox-artifact-${lower(var.environment)}-${random_uuid.artifact.result}", 0, 63)
  region = var.bucket_region
  acl    = "private"
}

resource "digitalocean_spaces_bucket" "immutable" {
  name   = substr("chillbox-immutable-${lower(var.environment)}-${random_uuid.immutable.result}", 0, 63)
  region = var.bucket_region
  acl    = "public-read"
}

output "immutable_bucket_name" {
  value       = digitalocean_spaces_bucket.immutable.name
  description = "Immutable bucket name is used by the NGINX server when serving a site's static resources."
}
output "artifact_bucket_name" {
  value       = digitalocean_spaces_bucket.artifact.name
  description = "Artifact bucket name is used to store artifact files."
}
output "sites_artifact" {
  value       = data.external.build_artifacts.result.sites_artifact
  description = "Sites artifact file."
}
output "chillbox_artifact" {
  value       = data.external.build_artifacts.result.chillbox_artifact
  description = "Chillbox artifact file."
}


resource "local_file" "host_inventory" {
  filename        = "${lower(var.environment)}/host_inventory.ansible.cfg"
  file_permission = "0400"
  content         = <<-HOST_INVENTORY
  [all:vars]
  tech_email=${var.tech_email}

  [chillbox]
  %{for ipv4_address in compact(flatten([digitalocean_droplet.chillbox[*].ipv4_address]))~}
  ${ipv4_address}
  %{endfor~}

  [chillbox:vars]
  domain_name=${var.sub_domain}${var.domain}
  HOST_INVENTORY
}
