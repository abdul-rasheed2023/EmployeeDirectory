output "sns_topic_arn" {
  value = aws_sns_topic.upload_status.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.s3_processor.function_name
}
