output "vpc_id" {
  value = module.network.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_update_kubeconfig_command" {
  description = "Run this locally to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "bastion_public_ip" {
  value = module.compute.bastion_public_ip
}

output "rds_endpoint" {
  value = module.data.rds_endpoint
}

output "rds_master_user_secret_arn" {
  description = "Fetch RDS master credentials at runtime: aws secretsmanager get-secret-value --secret-id <this-arn>"
  value       = module.data.rds_master_user_secret_arn
}

output "s3_bucket_name" {
  value = module.data.s3_bucket_id
}

output "dynamodb_table_name" {
  value = module.data.dynamodb_table_name
}

output "sns_topic_arn" {
  value = module.notifications.sns_topic_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL — use this in CI/CD pipelines to push images"
  value       = module.ecr.repository_url
}

output "ecr_registry_id" {
  description = "AWS account ID for the ECR registry"
  value       = module.ecr.registry_id
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

output "ci_oidc_role_arn" {
  value = module.ci_oidc.role_arn
}

output "oidc_provider_arn" {
  value = module.ci_oidc.oidc_provider_arn
}