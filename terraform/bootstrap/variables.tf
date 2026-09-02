variable "aws_region" {
  type        = string
  description = "Region to create the state bucket and lock table in"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Prefix used for naming the bucket and table — match your main project's project_name"
  default     = "xyz-company"
}

variable "state_bucket_suffix" {
  type        = string
  description = "A short unique string (e.g. your initials + a few digits) to make the S3 bucket name globally unique"
}
