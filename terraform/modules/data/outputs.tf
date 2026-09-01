output "s3_bucket_id" {
  value = aws_s3_bucket.employee_assets.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.employee_assets.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.image_metadata.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.image_metadata.arn
}

output "rds_endpoint" {
  value = aws_db_instance.mysql_db.endpoint
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master credentials (managed by AWS, rotatable)"
  value       = aws_db_instance.mysql_db.master_user_secret[0].secret_arn
}
