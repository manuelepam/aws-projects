data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_kinesis_stream" "stock_market" {
  name             = "stock-market-stream"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

resource "aws_s3_bucket" "raw" {
  bucket = "stock-market-raw-data-8f3c2a"
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "cleaned" {
  name         = "stock-market-cleaned"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "symbol"
  range_key    = "ingested_at"

  attribute {
    name = "symbol"
    type = "S"
  }

  attribute {
    name = "ingested_at"
    type = "S"
  }
}

resource "aws_sns_topic" "anomalies" {
  name = "stock-market-anomalies"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn                       = aws_sns_topic.anomalies.arn
  protocol                        = "email"
  endpoint                        = var.alert_email
  confirmation_timeout_in_minutes = 1
  endpoint_auto_confirms          = false

  lifecycle {
    # These creation-time settings are not returned by the SNS API after import.
    ignore_changes = [confirmation_timeout_in_minutes, endpoint_auto_confirms]
  }
}

resource "aws_secretsmanager_secret" "finnhub" {
  name                           = "stock-market/finnhub-api"
  description                    = "Finnhub API key used by the scheduled stock data producer Lambda"
  force_overwrite_replica_secret = false
  recovery_window_in_days        = 30

  lifecycle {
    # These deletion/replica defaults are not returned by the API after import.
    ignore_changes = [force_overwrite_replica_secret, recovery_window_in_days]
  }
}

# The secret value is deliberately not managed by Terraform. Keeping it out of
# configuration and state avoids storing the Finnhub API key in plaintext state.

data "archive_file" "producer" {
  type        = "zip"
  source_file = "${path.module}/../lambda/producer/lambda_function.py"
  output_path = "${path.module}/producer.zip"
}

data "archive_file" "processor" {
  type        = "zip"
  source_file = "${path.module}/../lambda/processor/lambda_function.py"
  output_path = "${path.module}/processor.zip"
}

resource "aws_iam_role" "producer" {
  name = "stock-data-producer-role-zaue31he"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "producer_logging" {
  name = "AWSLambdaBasicExecutionRole-c1f4807d-0f05-4bce-a4ea-777ef6d16a61"
  path = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/stock-data-producer:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "producer_logging" {
  role       = aws_iam_role.producer.name
  policy_arn = aws_iam_policy.producer_logging.arn
}

resource "aws_iam_role_policy" "producer_access" {
  name = "StockDataProducerAccessPolicy"
  role = aws_iam_role.producer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteStockRecordsToKinesis"
        Effect   = "Allow"
        Action   = "kinesis:PutRecord"
        Resource = aws_kinesis_stream.stock_market.arn
      },
      {
        Sid      = "ReadFinnhubApiKey"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:stock-market/finnhub-api-*"
      }
    ]
  })
}

resource "aws_iam_role" "processor" {
  name = "stock-data-processor-role-2a0l83oc"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "processor_logging" {
  name = "AWSLambdaBasicExecutionRole-73beb8ff-bcc8-488b-b260-91a4ba0de16a"
  path = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/stock-data-processor:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "processor_logging" {
  role       = aws_iam_role.processor.name
  policy_arn = aws_iam_policy.processor_logging.arn
}

resource "aws_iam_role_policy_attachment" "processor_kinesis" {
  role       = aws_iam_role.processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole"
}

resource "aws_iam_role_policy" "processor_storage" {
  name = "StockMarketStorageWritePolicy"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteCleanedRecords"
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.cleaned.arn
      },
      {
        Sid      = "ArchiveRawRecords"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.raw.arn}/raw/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "processor_alerts" {
  name = "StockMarketAnomalyPublishPolicy"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PublishStockAnomalyAlerts"
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.anomalies.arn
    }]
  })
}

resource "aws_lambda_function" "producer" {
  function_name    = "stock-data-producer"
  role             = aws_iam_role.producer.arn
  filename         = data.archive_file.producer.output_path
  source_code_hash = data.archive_file.producer.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 15

  environment {
    variables = {
      SECRET_ID   = aws_secretsmanager_secret.finnhub.name
      STREAM_NAME = aws_kinesis_stream.stock_market.name
      SYMBOLS     = "AAPL,MSFT,AMZN"
    }
  }

}

resource "aws_lambda_function" "processor" {
  function_name    = "stock-data-processor"
  role             = aws_iam_role.processor.arn
  filename         = data.archive_file.processor.output_path
  source_code_hash = data.archive_file.processor.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 15

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cleaned.name
      RAW_BUCKET     = aws_s3_bucket.raw.id
      SNS_TOPIC_ARN  = aws_sns_topic.anomalies.arn
    }
  }

}

resource "aws_cloudwatch_log_group" "producer" {
  name              = "/aws/lambda/stock-data-producer"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/stock-data-processor"
  retention_in_days = 14
}

resource "aws_lambda_event_source_mapping" "stock_market" {
  event_source_arn  = aws_kinesis_stream.stock_market.arn
  function_name     = aws_lambda_function.processor.arn
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = var.pipeline_enabled

  lifecycle {
    # AWS returns an empty metrics block that provider v5 cannot represent.
    ignore_changes = [metrics_config]
  }
}

resource "aws_glue_catalog_database" "analytics" {
  name = "stock_market_analytics"
}

resource "aws_glue_catalog_table" "raw" {
  name          = "stock_market_raw"
  database_name = aws_glue_catalog_database.analytics.name
  table_type    = "EXTERNAL_TABLE"
  owner         = "hadoop"

  parameters = {
    EXTERNAL                    = "TRUE"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2026,2035"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "projection.hour.type"      = "integer"
    "projection.hour.range"     = "0,23"
    "projection.hour.digits"    = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.raw.id}/raw/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/"
    "transient_lastDdlTime"     = "1786264095"
  }

  storage_descriptor {
    location          = "s3://${aws_s3_bucket.raw.id}/raw"
    input_format      = "org.apache.hadoop.mapred.TextInputFormat"
    output_format     = "org.apache.hadoop.hive.ql.io.IgnoreKeyTextOutputFormat"
    number_of_buckets = -1

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    skewed_info {
      skewed_column_names               = []
      skewed_column_values              = []
      skewed_column_value_location_maps = {}
    }

    columns {
      name = "symbol"
      type = "string"
    }
    columns {
      name = "provider"
      type = "string"
    }
    columns {
      name = "ingested_at"
      type = "string"
    }
    columns {
      name = "quote"
      type = "struct<c:double,d:double,dp:double,h:double,l:double,o:double,pc:double,t:bigint>"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}

resource "aws_iam_role" "scheduler" {
  name = "EventBridgeSchedulerStockProducerRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
      }
    }]
  })
}

resource "aws_iam_policy" "scheduler_invoke" {
  name = "Amazon-EventBridge-Scheduler-Execution-Policy-086518a7-23d3-4758-8b2b-917570b1ad0d"
  path = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "lambda:InvokeFunction"
      Resource = [
        aws_lambda_function.producer.arn,
        "${aws_lambda_function.producer.arn}:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler_invoke" {
  role       = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.scheduler_invoke.arn
}

resource "aws_scheduler_schedule" "market_open" {
  name                         = "stock-data-producer-market-ope"
  group_name                   = "default"
  state                        = var.pipeline_enabled ? "ENABLED" : "DISABLED"
  schedule_expression          = "cron(30/5 9 ? * MON-FRI *)"
  schedule_expression_timezone = "America/New_York"

  flexible_time_window { mode = "OFF" }

  target {
    arn      = aws_lambda_function.producer.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{}"

    retry_policy {
      maximum_event_age_in_seconds = 300
      maximum_retry_attempts       = 1
    }
  }
}

resource "aws_scheduler_schedule" "market_hours" {
  name                         = "stock-data-producer-market-hours"
  group_name                   = "default"
  state                        = var.pipeline_enabled ? "ENABLED" : "DISABLED"
  schedule_expression          = "cron(0/5 10-15 ? * MON-FRI *)"
  schedule_expression_timezone = "America/New_York"

  flexible_time_window { mode = "OFF" }

  target {
    arn      = aws_lambda_function.producer.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{}"

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 0
    }
  }
}

# Keep the old rule under management while disabled. It is retained for audit
# history but no longer invokes the producer around the clock.
resource "aws_cloudwatch_event_rule" "legacy_schedule" {
  name                = "stock-data-producer-schedule"
  description         = "Fetch stock quotes every 5 minutes"
  schedule_expression = "rate(5 minutes)"
  state               = "DISABLED"
}

resource "aws_cloudwatch_event_target" "legacy_producer" {
  rule      = aws_cloudwatch_event_rule.legacy_schedule.name
  target_id = "ndd6fi0e3pirupjogvcw"
  arn       = aws_lambda_function.producer.arn
}
