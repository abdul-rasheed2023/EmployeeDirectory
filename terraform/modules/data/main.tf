# ==============================================================================
# DATA MODULE
# S3 bucket (employee photos), DynamoDB table (image metadata), and the
# RDS MySQL instance (relational profile data).
# ==============================================================================

# --- S3 bucket ---
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "employee_assets" {
  bucket        = "${var.name_prefix}-employee-profile-assets-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-employee-assets-bucket" })
}

resource "aws_s3_bucket_ownership_controls" "s3_oc" {
  bucket = aws_s3_bucket.employee_assets.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_block" {
  bucket = aws_s3_bucket.employee_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table ---
resource "aws_dynamodb_table" "image_metadata" {
  name         = "${var.name_prefix}-employee-image-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "EmployeeID"
  range_key    = "ImageID"

  attribute {
    name = "EmployeeID"
    type = "S"
  }

  attribute {
    name = "ImageID"
    type = "S"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-dynamodb-metadata-table" })
}

# --- RDS MySQL ---
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${var.name_prefix}-rds-private-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds-private-subnet-group" })
}

resource "aws_db_instance" "mysql_db" {
  identifier              = "${var.name_prefix}-profile-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage            = 20
  max_allocated_storage        = 100
  db_name                      = "xyz_company_db"
  username                     = "admin"
  manage_master_user_password  = true
  db_subnet_group_name         = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids       = [var.rds_sg_id]
  skip_final_snapshot          = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-profile-mysql-instance" })
}
