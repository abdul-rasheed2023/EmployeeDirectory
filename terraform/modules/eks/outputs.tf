output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group, auto-attached to the control plane and node ENIs"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  value = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "oidc_provider_arn" {
  description = "Needed when creating IRSA roles later (per-pod IAM permissions)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  value = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}
