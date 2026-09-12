# ==============================================================================
# APP-IRSA MODULE
# IAM role assumable by the employee-directory pod's Kubernetes ServiceAccount
# via OIDC federation (IRSA), scoped to exactly what the app needs:
#   - S3: read/write employee photo objects
#   - DynamoDB: read/write image metadata
#   - Secrets Manager: read/write the Data Protection key ring (ASP.NET Core
#     writes key XML into it at runtime, and needs to read it back)
# Same trust-policy pattern as modules/lb-controller-irsa.
# ==============================================================================

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name_prefix}-app-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-app-irsa-role" })
}

data "aws_iam_policy_document" "app_access" {
  statement {
    sid    = "S3PhotoAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${var.s3_bucket_arn}/*"]
  }

  statement {
    sid       = "S3ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.s3_bucket_arn]
  }

  statement {
    sid    = "DynamoDBMetadataAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = [var.dynamodb_table_arn]
  }

  statement {
    sid    = "DataProtectionKeyRingAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [var.data_protection_secret_arn]
  }
}

resource "aws_iam_policy" "app_access" {
  name   = "${var.name_prefix}-app-irsa-policy"
  policy = data.aws_iam_policy_document.app_access.json

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-app-irsa-policy" })
}

resource "aws_iam_role_policy_attachment" "app_access" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_access.arn
}