output "role_arn" {
  description = "IAM role ARN to set as APP_IRSA_ROLE_ARN when rendering k8s/base/serviceaccount.yaml"
  value       = aws_iam_role.app.arn
}