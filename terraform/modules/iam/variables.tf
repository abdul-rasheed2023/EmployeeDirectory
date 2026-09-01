variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket EC2 and Lambda roles are scoped to"
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the DynamoDB table EC2 and Lambda roles are scoped to"
}
