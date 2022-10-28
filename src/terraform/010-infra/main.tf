terraform {
  required_providers {
    # UPKEEP due: "2022-12-04" label: "Terraform provider digitalocean/digitalocean" interval: "+2 months"
    # https://registry.terraform.io/providers/digitalocean/digitalocean/latest
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.22.3"
    }
  }
}

provider "digitalocean" {
  token             = var.do_token
  spaces_access_id  = var.do_spaces_access_key_id
  spaces_secret_key = var.do_spaces_secret_access_key
}

resource "digitalocean_project" "chillbox-infra" {
  name        = "ChillBox Infrastructure - ${var.chillbox_instance} ${var.environment} ${regex("(^[^+]+)\\+?", var.project_version)[0]}"
  description = var.project_description
  purpose     = "Website Hosting"
  environment = var.project_environment
  resources = compact([
    digitalocean_spaces_bucket.artifact.urn,
    digitalocean_spaces_bucket.immutable.urn,
  ])
}

resource "random_uuid" "immutable" {}
resource "random_uuid" "artifact" {}

resource "digitalocean_spaces_bucket" "artifact" {
  name   = "${substr("chillbox-artifact-${lower(var.environment)}-${lower(var.chillbox_instance)}-${replace(random_uuid.artifact.result, "-", "")}", 0, 60)}cb"
  region = var.bucket_region
  acl    = "private"
}

resource "digitalocean_spaces_bucket" "immutable" {
  name   = "${substr("chillbox-immutable-${lower(var.environment)}-${lower(var.chillbox_instance)}-${replace(random_uuid.immutable.result, "-", "")}", 0, 60)}cb"
  region = var.bucket_region
  acl    = "public-read"
}

resource "random_string" "initial_dev_user_password" {
  length      = 64
  special     = false
  lower       = true
  upper       = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3

  provisioner "local-exec" {
    command    = "openssl passwd -6 '${self.result}' > /var/lib/terraform-010-infra/dev_user_passphrase_hashed"
    on_failure = fail
  }
  provisioner "local-exec" {
    when       = destroy
    command    = "rm -f /var/lib/terraform-010-infra/dev_user_passphrase_hashed"
    on_failure = continue
  }
}

resource "random_string" "chillbox_ansibledev_pass" {
  count       = var.chillbox_count
  length      = 128
  special     = false
  lower       = true
  upper       = true
  min_lower   = 13
  min_upper   = 13
  min_numeric = 13

  provisioner "local-exec" {
    command    = "openssl passwd -6 '${self[count.index].result}' > /var/lib/terraform-010-infra/chillbox_ansibledev_pass_hashed-${count.index}"
    on_failure = fail
  }
  provisioner "local-exec" {
    when       = destroy
    command    = "rm -f /var/lib/terraform-010-infra/chillbox_ansibledev_pass_hashed-${count.index}"
    on_failure = continue
  }
}

resource "random_string" "bootstrap_chillbox_pass" {
  length      = 128
  special     = false
  lower       = true
  upper       = true
  min_lower   = 13
  min_upper   = 13
  min_numeric = 13
}

resource "local_sensitive_file" "bootstrap_chillbox_init_credentials" {
  filename        = "/run/tmp/secrets/terraform-010-infra/bootstrap-chillbox-init-credentials.sh"
  file_permission = "0500"
  content = templatefile("bootstrap-chillbox-init-credentials.sh.tftpl", {
    tf_developer_public_ssh_keys : "%{for public_ssh_key in var.developer_public_ssh_keys} ${public_ssh_key}\n %{endfor}",
    tf_access_key_id : var.do_chillbox_spaces_access_key_id,
    tf_secret_access_key : var.do_chillbox_spaces_secret_access_key,
    tf_tech_email : var.tech_email,
    tf_immutable_bucket_name : digitalocean_spaces_bucket.immutable.name,
    tf_immutable_bucket_domain_name : "${digitalocean_spaces_bucket.immutable.name}.${var.bucket_region}.digitaloceanspaces.com",
    tf_artifact_bucket_name : digitalocean_spaces_bucket.artifact.name,
    tf_sites_artifact : var.sites_artifact,
    tf_chillbox_artifact : var.chillbox_artifact
    tf_s3_endpoint_url : "https://${digitalocean_spaces_bucket.artifact.region}.digitaloceanspaces.com/",
    tf_chillbox_server_name : "${var.sub_domain}${var.domain}",
  })
}


resource "null_resource" "bootstrap_chillbox_init_credentials" {
  triggers = {
    bootstrap_chillbox_init_credentials = "${local_sensitive_file.bootstrap_chillbox_init_credentials.id}"
  }

  provisioner "local-exec" {
    command = "openssl enc -aes-256-cbc -e -md sha512 -pbkdf2 -a -iter 100000 -salt -pass 'pass:${random_string.bootstrap_chillbox_pass.result}' -in '${local_sensitive_file.bootstrap_chillbox_init_credentials.filename}' -out '/var/lib/terraform-010-infra/bootstrap-chillbox-init-credentials.sh.encrypted'"
  }
}
