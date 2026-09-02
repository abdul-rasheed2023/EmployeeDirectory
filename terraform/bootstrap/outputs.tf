output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.id
  description = "Copy this into backend.tf -> bucket ="
}

output "lock_table_name" {
  value       = aws_dynamodb_table.tf_lock.name
  description = "Copy this into backend.tf -> dynamodb_table ="
}

output "region" {
  value       = var.aws_region
  description = "Copy this into backend.tf -> region ="
}
