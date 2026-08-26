output "kinesis_stream_name" {
  description = "Name of the Kinesis security-events stream"
  value       = aws_kinesis_stream.security_events.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis security-events stream"
  value       = aws_kinesis_stream.security_events.arn
}
