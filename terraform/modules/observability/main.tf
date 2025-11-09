# Real-time CloudTrail logging to CloudWatch
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.cluster_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.cluster_name}-cloudtrail-logs"
  }
}

# IAM role for CloudTrail to write to CloudWatch
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.cluster_name}-cloudtrail-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "cloudtrail-cloudwatch-logs"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# CloudTrail with CloudWatch integration
resource "aws_cloudtrail" "main" {
  name                          = "${var.cluster_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name = "${var.cluster_name}-cloudtrail"
  }
}

# EventBridge rule for EKS events (real-time)
resource "aws_cloudwatch_event_rule" "eks_events" {
  name        = "${var.cluster_name}-eks-events"
  description = "Capture EKS API calls in real-time"

  event_pattern = jsonencode({
    source = ["aws.eks"]
  })
}

resource "aws_cloudwatch_event_target" "eks_logs" {
  rule      = aws_cloudwatch_event_rule.eks_events.name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.cloudtrail.arn
}

# CloudWatch Log Group for EventBridge
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
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}
