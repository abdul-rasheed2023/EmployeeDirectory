output "role_arn" {
  description = "IAM role ARN to set in the Helm values as serviceAccount.annotations.eks.amazonaws.com/role-arn"
  value       = aws_iam_role.lb_controller.arn
}