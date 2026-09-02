variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "notification_email" {
  type        = string
  description = "Email address subscribed to the SNS upload-status topic"
}

variable "lambda_role_arn" {
  type        = string
  description = "IAM role ARN the Lambda function assumes"
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table name injected into the Lambda environment"
}

variable "s3_bucket_id" {
  type        = string
  description = "S3 bucket that triggers the Lambda on object creation"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket, used in the Lambda invoke permission"
}
