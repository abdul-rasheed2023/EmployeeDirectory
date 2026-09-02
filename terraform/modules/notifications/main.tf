# ==============================================================================
# NOTIFICATIONS MODULE
# S3 upload triggers a Lambda function, which writes metadata to DynamoDB
# and publishes to an SNS topic that emails a subscriber.
# ==============================================================================

data "aws_caller_identity" "current" {}

# --- SNS topic + subscription ---
resource "aws_sns_topic" "upload_status" {
  name = "${var.name_prefix}-upload-success-topic"

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-upload-sns-topic" })
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.upload_status.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# --- Lambda function ---
resource "local_file" "lambda_code" {
  filename = "${path.module}/lambda/index.py"
  content  = <<-EOT
    import json
    import boto3

    def handler(event, context):
        print("S3 Object Upload Event Detected!")
        print("Event Data:", json.dumps(event))
        # Add your metadata mining and DynamoDB/SNS code here
        return {"statusCode": 200, "body": "Success"}
  EOT
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.lambda_code.filename
  output_path = "${path.module}/lambda/lambda_function.zip"
}

resource "aws_lambda_function" "s3_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.name_prefix}-s3-photo-metadata-processor"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      SNS_TOPIC_ARN  = aws_sns_topic.upload_status.arn
    }
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-s3-event-lambda" })
}

# --- S3 -> Lambda event wiring ---
resource "aws_lambda_permission" "allow_s3" {
  statement_id   = "AllowExecutionFromS3Bucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.s3_processor.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = var.s3_bucket_arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.s3_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
