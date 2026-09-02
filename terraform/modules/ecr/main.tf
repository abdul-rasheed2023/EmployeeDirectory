# ==============================================================================
# ECR MODULE
# Elastic Container Registry for storing Docker images built by the CI/CD
# pipeline. Includes lifecycle policies to expire old images and scan-on-push
# to detect vulnerabilities before deployment.
# ==============================================================================

resource "aws_ecr_repository" "employee_directory" {
  name            = "${var.name_prefix}-employee-directory"
  image_tag_mutability       = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ecr-repository"
  })
}

# Lifecycle policy: expire old/untagged images to keep costs down
resource "aws_ecr_lifecycle_policy" "employee_directory" {
  repository = aws_ecr_repository.employee_directory.name

  policy = jsonencode({
    rules = [
      # Rule 1: Expire untagged images after 30 days
      {
        rulePriority = 1
        description  = "Expire untagged images after 30 days"
        selection = {
          tagStatus     = "untagged"
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },

      # Rule 2: Keep only the last 10 images with version tags (v*)
      # This allows rollback to recent versions without bloat
      {
        rulePriority = 2
        description  = "Keep last 10 released images (v* tags)"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },

      # Rule 3: Expire development/branch images after 7 days
      # Keeps CI/CD branch builds from accumulating
      {
        rulePriority = 3
        description  = "Expire dev/branch images after 7 days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "feat-", "fix-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository policy: allow EKS node role to pull images
# This is the trust relationship that lets your Kubernetes nodes
# pull images without needing separate credentials
data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "allow_eks_nodes" {
  repository = aws_ecr_repository.employee_directory.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodesPull"
        Effect = "Allow"
        Principal = {
          AWS = var.eks_node_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }      
    ]
  })
}