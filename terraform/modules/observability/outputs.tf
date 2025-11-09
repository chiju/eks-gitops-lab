output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for all AWS API calls"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}
