# CloudWatch Dashboard for real-time EKS monitoring
resource "aws_cloudwatch_dashboard" "eks_operations" {
  dashboard_name = "${var.cluster_name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "log"
        properties = {
          query   = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.eks_events.name}'
            | fields @timestamp, detail.eventName, detail.userIdentity.principalId
            | sort @timestamp desc
            | limit 20
          EOT
          region  = data.aws_region.current.name
          title   = "Recent EKS API Calls"
        }
      },
      {
        type = "log"
        properties = {
          query   = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.eks_events.name}'
            | fields @timestamp, detail.eventName, detail.errorCode
            | filter ispresent(detail.errorCode)
            | sort @timestamp desc
            | limit 20
          EOT
          region  = data.aws_region.current.name
          title   = "EKS API Errors"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
