# Real-time EKS event logging (no S3 needed!)
resource "aws_cloudwatch_log_group" "eks_events" {
  name              = "/aws/events/${var.cluster_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.cluster_name}-eks-events"
  }
}

# EventBridge rule for EKS events (real-time, no CloudTrail delay)
resource "aws_cloudwatch_event_rule" "eks_events" {
  name        = "${var.cluster_name}-eks-events"
  description = "Capture all EKS API calls in real-time"

  event_pattern = jsonencode({
    source = ["aws.eks"]
  })
}

resource "aws_cloudwatch_event_target" "eks_logs" {
  rule      = aws_cloudwatch_event_rule.eks_events.name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.eks_events.arn
}

# Allow EventBridge to write to CloudWatch Logs
resource "aws_cloudwatch_log_resource_policy" "eventbridge" {
  policy_name = "${var.cluster_name}-eventbridge-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "events.amazonaws.com",
          "delivery.logs.amazonaws.com"
        ]
      }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.eks_events.arn}:*"
    }]
  })
}
