import {
  to = aws_kinesis_stream.stock_market
  id = "stock-market-stream"
}
import {
  to = aws_s3_bucket.raw
  id = "stock-market-raw-data-8f3c2a"
}
import {
  to = aws_s3_bucket_public_access_block.raw
  id = "stock-market-raw-data-8f3c2a"
}
import {
  to = aws_s3_bucket_server_side_encryption_configuration.raw
  id = "stock-market-raw-data-8f3c2a"
}
import {
  to = aws_dynamodb_table.cleaned
  id = "stock-market-cleaned"
}
import {
  to = aws_sns_topic.anomalies
  id = "arn:aws:sns:eu-north-1:436856560914:stock-market-anomalies"
}
import {
  to = aws_sns_topic_subscription.email
  id = "arn:aws:sns:eu-north-1:436856560914:stock-market-anomalies:da85a37e-aedd-4acb-89f7-9ef659169bd1"
}
import {
  to = aws_secretsmanager_secret.finnhub
  id = "arn:aws:secretsmanager:eu-north-1:436856560914:secret:stock-market/finnhub-api-yV6xC4"
}

import {
  to = aws_iam_role.producer
  id = "stock-data-producer-role-zaue31he"
}
import {
  to = aws_iam_policy.producer_logging
  id = "arn:aws:iam::436856560914:policy/service-role/AWSLambdaBasicExecutionRole-c1f4807d-0f05-4bce-a4ea-777ef6d16a61"
}
import {
  to = aws_iam_role_policy_attachment.producer_logging
  id = "stock-data-producer-role-zaue31he/arn:aws:iam::436856560914:policy/service-role/AWSLambdaBasicExecutionRole-c1f4807d-0f05-4bce-a4ea-777ef6d16a61"
}
import {
  to = aws_iam_role_policy.producer_access
  id = "stock-data-producer-role-zaue31he:StockDataProducerAccessPolicy"
}

import {
  to = aws_iam_role.processor
  id = "stock-data-processor-role-2a0l83oc"
}
import {
  to = aws_iam_policy.processor_logging
  id = "arn:aws:iam::436856560914:policy/service-role/AWSLambdaBasicExecutionRole-73beb8ff-bcc8-488b-b260-91a4ba0de16a"
}
import {
  to = aws_iam_role_policy_attachment.processor_logging
  id = "stock-data-processor-role-2a0l83oc/arn:aws:iam::436856560914:policy/service-role/AWSLambdaBasicExecutionRole-73beb8ff-bcc8-488b-b260-91a4ba0de16a"
}
import {
  to = aws_iam_role_policy_attachment.processor_kinesis
  id = "stock-data-processor-role-2a0l83oc/arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole"
}
import {
  to = aws_iam_role_policy.processor_storage
  id = "stock-data-processor-role-2a0l83oc:StockMarketStorageWritePolicy"
}
import {
  to = aws_iam_role_policy.processor_alerts
  id = "stock-data-processor-role-2a0l83oc:StockMarketAnomalyPublishPolicy"
}

import {
  to = aws_lambda_function.producer
  id = "stock-data-producer"
}
import {
  to = aws_lambda_function.processor
  id = "stock-data-processor"
}
import {
  to = aws_cloudwatch_log_group.producer
  id = "/aws/lambda/stock-data-producer"
}
import {
  to = aws_cloudwatch_log_group.processor
  id = "/aws/lambda/stock-data-processor"
}
import {
  to = aws_lambda_event_source_mapping.stock_market
  id = "5a989521-91de-45f6-b202-87046a4e5928"
}

import {
  to = aws_glue_catalog_database.analytics
  id = "436856560914:stock_market_analytics"
}
import {
  to = aws_glue_catalog_table.raw
  id = "436856560914:stock_market_analytics:stock_market_raw"
}

import {
  to = aws_iam_role.scheduler
  id = "EventBridgeSchedulerStockProducerRole"
}
import {
  to = aws_iam_policy.scheduler_invoke
  id = "arn:aws:iam::436856560914:policy/service-role/Amazon-EventBridge-Scheduler-Execution-Policy-086518a7-23d3-4758-8b2b-917570b1ad0d"
}
import {
  to = aws_iam_role_policy_attachment.scheduler_invoke
  id = "EventBridgeSchedulerStockProducerRole/arn:aws:iam::436856560914:policy/service-role/Amazon-EventBridge-Scheduler-Execution-Policy-086518a7-23d3-4758-8b2b-917570b1ad0d"
}
import {
  to = aws_scheduler_schedule.market_open
  id = "default/stock-data-producer-market-ope"
}
import {
  to = aws_scheduler_schedule.market_hours
  id = "default/stock-data-producer-market-hours"
}

import {
  to = aws_cloudwatch_event_rule.legacy_schedule
  id = "stock-data-producer-schedule"
}
import {
  to = aws_cloudwatch_event_target.legacy_producer
  id = "stock-data-producer-schedule/ndd6fi0e3pirupjogvcw"
}
