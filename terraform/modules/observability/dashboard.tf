# CloudWatch Dashboard for complete AWS account visibility
resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.cluster_name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | fields @timestamp, eventName, userIdentity.principalId, eventSource
            | sort @timestamp desc
            | limit 50
          EOT
          region = data.aws_region.current.name
          title  = "All AWS API Calls (Real-time)"
        }
      },
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | fields @timestamp, eventName, userIdentity.principalId
            | filter eventSource = "eks.amazonaws.com"
            | sort @timestamp desc
            | limit 20
          EOT
          region = data.aws_region.current.name
          title  = "EKS API Calls"
        }
      },
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | fields @timestamp, eventName, errorCode, errorMessage
            | filter ispresent(errorCode)
            | sort @timestamp desc
            | limit 20
          EOT
          region = data.aws_region.current.name
          title  = "All API Errors"
        }
      },
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | stats count() by eventSource
            | sort count desc
            | limit 10
          EOT
          region = data.aws_region.current.name
          title  = "Top 10 AWS Services Used"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
