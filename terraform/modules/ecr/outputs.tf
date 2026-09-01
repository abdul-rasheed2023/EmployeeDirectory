output "repository_url" {
  description = "ECR repository URL for pushing images (used in CI/CD pipeline)"
  value       = aws_ecr_repository.employee_directory.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.employee_directory.arn
}

output "registry_id" {
  description = "AWS account ID where ECR repository lives"
  value       = aws_ecr_repository.employee_directory.registry_id
}

output "repository_name" {
  description = "Name of the ECR repository (useful for CLI commands)"
  value       = aws_ecr_repository.employee_directory.name
}