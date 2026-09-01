variable "name_prefix" {
  description = "Prefix for resource names (e.g., project-env)"
  type        = string
}

variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "eks_node_role_arn" {
  description = "ARN of the EKS node role — used to allow nodes to pull images from ECR"
  type        = string
}
