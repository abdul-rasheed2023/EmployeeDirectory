output "role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via aws-actions/configure-aws-credentials"
  value       = aws_iam_role.github_actions_ecr_push.arn
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}
