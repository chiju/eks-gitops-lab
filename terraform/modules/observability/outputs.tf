output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for EKS events"
  value       = aws_cloudwatch_log_group.eks_events.name
}

output "eventbridge_rule" {
  description = "EventBridge rule for EKS events"
  value       = aws_cloudwatch_event_rule.eks_events.name
}
