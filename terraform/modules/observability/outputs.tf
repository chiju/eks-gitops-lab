output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.main.arn
}
