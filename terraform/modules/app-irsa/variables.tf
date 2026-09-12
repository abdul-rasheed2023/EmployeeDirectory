variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
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
  default     = "default"
  description = "Namespace the app's ServiceAccount lives in"
}

variable "service_account_name" {
  type        = string
  default     = "employee-directory"
  description = "Name of the app's Kubernetes ServiceAccount"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket holding employee photo assets"
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the DynamoDB image-metadata table"
}

variable "data_protection_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager Data Protection key ring"
}