output "cluster_name" {
  value = local.cluster_name
}

output "deployed_image" {
  value = "${data.terraform_remote_state.infra.outputs.ecr_repository_url}:${var.image_tag}"
}
