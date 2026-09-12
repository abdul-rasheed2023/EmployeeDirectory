output "role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via aws-actions/configure-aws-credentials"
  value       = aws_iam_role.github_actions_ecr_push.arn
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}

output "plan_role_arn" {
  description = "IAM role ARN for PR-triggered terraform plan workflows to assume via aws-actions/configure-aws-credentials"
  value       = var.create_plan_role ? aws_iam_role.github_actions_terraform_plan[0].arn : null
}
