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

data "archive_file" "lambda_package" {
  type        = "zip"
  output_path = "${path.module}/.terraform/lambda_package.zip"

  source {
    content  = file("${path.module}/../src/__init__.py")
    filename = "src/__init__.py"
  }

  source {
    content  = file("${path.module}/../src/detector.py")
    filename = "src/detector.py"
  }

  source {
    content  = file("${path.module}/../src/lambda_handler.py")
    filename = "src/lambda_handler.py"
  }
}

resource "aws_iam_role" "lambda_execution" {
  name = "${local.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.project_name}-${var.environment}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${local.project_name}-${var.environment}-lambda-permissions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadSecurityEvents"
        Effect = "Allow"

        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards"
        ]

        Resource = aws_kinesis_stream.security_events.arn
      },
      {
        Sid      = "ListKinesisStreams"
        Effect   = "Allow"
        Action   = "kinesis:ListStreams"
        Resource = "*"
      },
      {
        Sid    = "DecryptKinesisRecords"
        Effect = "Allow"
        Action = "kms:Decrypt"

        Resource = "*"

        Condition = {
          StringEquals = {
            "kms:ViaService" = "kinesis.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      },
      {
        Sid      = "PublishSecurityAlerts"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

resource "aws_lambda_function" "threat_detector" {
  function_name = "${local.project_name}-${var.environment}"
  description   = "Detects suspicious authentication activity from Kinesis events"

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  role    = aws_iam_role.lambda_execution.arn
  runtime = "python3.13"
  handler = "src.lambda_handler.lambda_handler"

  memory_size = 128
  timeout     = 10

  environment {
    variables = {
      ALERT_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy.lambda_permissions,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

resource "aws_lambda_event_source_mapping" "kinesis_to_lambda" {
  event_source_arn  = aws_kinesis_stream.security_events.arn
  function_name     = aws_lambda_function.threat_detector.arn
  starting_position = "LATEST"

  maximum_retry_attempts        = 3
  maximum_record_age_in_seconds = 3600

  batch_size = 100
  enabled    = true

  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_sns_topic" "security_alerts" {
  name = "${local.project_name}-${var.environment}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "security_alert_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name        = "${local.project_name}-${var.environment}-lambda-errors"
  alarm_description = "Alerts when the threat detection Lambda reports an error"

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  statistic   = "Sum"
  period      = 60

  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.threat_detector.function_name
  }

  alarm_actions = [
    aws_sns_topic.security_alerts.arn
  ]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name        = "${local.project_name}-${var.environment}-lambda-throttles"
  alarm_description = "Alerts when the threat detection Lambda is throttled"

  namespace   = "AWS/Lambda"
  metric_name = "Throttles"
  statistic   = "Sum"
  period      = 60

  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.threat_detector.function_name
  }

  alarm_actions = [
    aws_sns_topic.security_alerts.arn
  ]

  tags = local.common_tags
}
