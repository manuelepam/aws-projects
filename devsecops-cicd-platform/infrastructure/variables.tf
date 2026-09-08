variable "aws_region" {
  description = "AWS region where project resources will be created"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "ecr_repository_name" {
  description = "Name of the Amazon ECR container repository"
  type        = string
  default     = "zephyrworks-turbine-api"
}
