# ==============================================================================
# BOOTSTRAP: Remote State Backend Resources
# ==============================================================================
# This is a SEPARATE, tiny Terraform project whose only job is to create the
# S3 bucket + DynamoDB table that the MAIN project's state will live in.
#
# Why separate? Chicken-and-egg problem: the main project's backend config
# needs a bucket/table to already exist before `terraform init` can use it.
# You can't have a project's remote backend be a resource managed by that
# same project's state. So: apply this once, manually, with local state
# (or none at all — these resources rarely change), then never touch it again.
#
# Run this ONCE:
#   cd bootstrap
#   terraform init
#   terraform apply
#   terraform output          <- copy these values into ../backend.tf
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- S3 bucket to hold the main project's terraform.tfstate ---
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-tfstate-${var.state_bucket_suffix}"

  # Prevents accidental deletion of your state bucket via terraform destroy
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "${var.project_name}-terraform-state"
    ManagedBy = "Terraform-Bootstrap"
    Purpose   = "remote-state-storage"
  }
}

# Versioning: lets you recover a previous state file if something corrupts
# the current one (e.g. a bad apply, or someone force-pushes bad state).
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest — state files can contain sensitive values
# (e.g. your db_password variable) in plain text.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — state files should never be publicly reachable.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table for state locking ---
# Prevents two people (or two CI runs) from running `terraform apply`
# against the same state at the same time and corrupting it.
resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # Required attribute name — Terraform expects exactly this

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.project_name}-terraform-lock"
    ManagedBy = "Terraform-Bootstrap"
    Purpose   = "state-locking"
  }
}
