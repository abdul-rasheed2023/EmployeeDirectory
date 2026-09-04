variable "name_prefix" {
  type        = string
  description = "Prefix applied to the IAM role name"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster's IAM OIDC provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS cluster OIDC issuer URL, without the https:// prefix"
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace the controller's service account lives in"
}

variable "service_account_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "Name of the controller's Kubernetes service account"
}