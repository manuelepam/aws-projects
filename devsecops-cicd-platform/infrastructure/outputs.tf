output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.application.name
}

output "ecr_repository_url" {
  description = "URL used to tag and push container images"
  value       = aws_ecr_repository.application.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.application.arn
}
