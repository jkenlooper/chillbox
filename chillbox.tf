

resource "local_file" "alpine_box_init" {
  filename = "bin/alpine-box-init.sh"
  file_permission = "0500"
  content = templatefile("alpine-box-init.sh.tftpl", {
    developer_ssh_key_github_list: "%{for username in var.developer_ssh_key_github} ${username} %{endfor}",
    access_key_id: var.access_key_id,
    secret_access_key: var.secret_access_key,
    tech_email: var.tech_email,
    immutable_bucket_name: local.immutable_bucket_name,
    artifact_bucket_name: local.artifact_bucket_name,
    sites_artifact: data.external.build_artifacts.result.sites_artifact,
  })
}
