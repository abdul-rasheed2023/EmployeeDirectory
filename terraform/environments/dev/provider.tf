# ==============================================================================
# REMOTE STATE BACKEND
# ==============================================================================
# State lives in S3 (versioned, encrypted, public access blocked). Locking
# uses S3's native lockfile mechanism (use_lockfile) so a second `apply`
# started while one is already running fails fast instead of racing and
# corrupting state.
#
# NOTE: DynamoDB-based locking (the `dynamodb_table` argument) is the older
# approach and is now deprecated by Terraform in favor of `use_lockfile`.
# The bootstrap/ project still creates a DynamoDB table - that was the
# standard pattern until recently and is worth knowing, but this project
# uses the current recommended S3-native locking instead. Requires
# Terraform >= 1.11.
#
# SETUP (one-time):
#   1. cd ../../bootstrap && terraform init && terraform apply
#   2. terraform output   <- copy the bucket name below
#   3. Fill in bucket below, then from environments/dev:
#      terraform init
#      Answer "yes" when asked to copy existing state to the new backend.
#
# NOTE: this block cannot use variables - backend config is evaluated before
# any variables are known, so the values must be hardcoded here.
# ==============================================================================

terraform {
  backend "s3" {
    bucket       = "xyz-company-tfstate-rasheed28aug2026"
    key          = "xyz-company/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}
