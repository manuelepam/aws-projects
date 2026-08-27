output "kinesis_stream_name" {
  description = "Name of the Kinesis security-events stream"
  value       = aws_kinesis_stream.security_events.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis security-events stream"
  value       = aws_kinesis_stream.security_events.arn
}

output "lambda_function_name" {
  description = "Name of the threat-detection Lambda function"
  value       = aws_lambda_function.threat_detector.function_name
}

output "lambda_function_arn" {
  description = "ARN of the threat-detection Lambda function"
  value       = aws_lambda_function.threat_detector.arn
}

output "lambda_log_group_name" {
  description = "CloudWatch log group used by the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "event_source_mapping_uuid" {
  description = "Identifier of the Kinesis-to-Lambda event-source mapping"
  value       = aws_lambda_event_source_mapping.kinesis_to_lambda.uuid
}
