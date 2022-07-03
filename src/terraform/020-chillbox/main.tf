terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
  spaces_access_id = var.do_spaces_access_key_id
  spaces_secret_key = var.do_spaces_secret_access_key
}

resource "digitalocean_project" "chillbox" {
  name        = "ChillBox - ${var.chillbox_instance} ${var.environment} ${var.project_version}"
  description = var.project_version
  purpose     = "Website Hosting"
  environment = var.project_environment
  resources = compact([
    one(digitalocean_droplet.chillbox[*].urn),
  ])
}

resource "digitalocean_vpc" "chillbox" {
  name        = "chillbox-${lower(var.chillbox_instance)}-${lower(var.environment)}"
  description = "ChillBox network for ${var.chillbox_instance} ${var.environment}"
  region      = var.region
  ip_range    = var.vpc_ip_range
}

resource "digitalocean_tag" "fw_developer_ssh" {
  name = "fw_chillbox_developer_ssh_${lower(var.chillbox_instance)}_${lower(var.environment)}"
}

resource "digitalocean_tag" "fw_web" {
  name = "fw_chillbox_web_${lower(var.chillbox_instance)}_${lower(var.environment)}"
}

resource "digitalocean_tag" "droplet" {
  name = "chillbox_droplet_${lower(var.chillbox_instance)}_${lower(var.environment)}"
}

resource "digitalocean_firewall" "developer_ssh" {
  name = "chillbox-developer-ssh-${lower(var.chillbox_instance)}-${lower(var.environment)}"
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
  name = "chillbox-web-${lower(var.chillbox_instance)}-${lower(var.environment)}"
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

resource "local_file" "host_inventory" {
  filename        = "/var/lib/terraform-020-chillbox/host_inventory.ansible.cfg"
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
