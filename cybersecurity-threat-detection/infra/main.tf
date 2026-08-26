terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }


    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "solent-dev"
}

locals {
  project_name = "solent-freight-threat-detection"

  common_tags = {
    Project     = local.project_name
    Company     = "Solent Freight Systems"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_kinesis_stream" "security_events" {
  name             = "${local.project_name}-${var.environment}"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = "alias/aws/kinesis"

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = local.common_tags
}
