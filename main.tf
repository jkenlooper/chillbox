terraform {
  required_providers {
  }
}

data "external" "build_artifacts" {
  program = ["./build-artifacts.sh"]
  query = {
    immutable_bucket_name = local.immutable_bucket_name
    artifact_bucket_name= local.artifact_bucket_name
    endpoint_url="http://localhost:9000/"
    chillbox_url="${var.chillbox_url}"
  }
}

resource "random_uuid" "immutable" {}
resource "random_uuid" "artifact" {}

locals {
  #immutable_bucket_name = substr("chillbox-immutable-${lower(var.environment)}-${random_uuid.immutable.result}", 0, 63)
  #artifact_bucket_name = substr("chillbox-artifact-${lower(var.environment)}-${random_uuid.artifact.result}", 0, 63)

  immutable_bucket_name="chillboximmutable"
  artifact_bucket_name="chillboxartifact"
  test = var.environment
}

output "immutable_bucket_name" {
  value = local.immutable_bucket_name
  description = "Immutable bucket name is used by the NGINX server when serving a site's static resources."
}
output "artifact_bucket_name" {
  value = local.artifact_bucket_name
  description = "Immutable bucket name is used by the NGINX server when serving a site's static resources."
}
output "endpoint_url" {
  # TODO
  value = "http://10.0.0.145:9000/"
  description = "The S3 endpoint URL."
}
output "sites_artifact" {
  value = data.external.build_artifacts.result.sites_artifact
  description = "Testing."
}
output "chillbox_artifact" {
  value = data.external.build_artifacts.result.chillbox_artifact
  description = "Testing."
}
