# CloudWatch Dashboard for real-time EKS monitoring
resource "aws_cloudwatch_dashboard" "eks_operations" {
  dashboard_name = "${var.cluster_name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | fields @timestamp, eventName, userIdentity.principalId, sourceIPAddress
            | filter eventSource = "eks.amazonaws.com"
            | sort @timestamp desc
            | limit 20
          EOT
          region = data.aws_region.current.name
          title  = "Recent EKS API Calls"
        }
      },
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | fields @timestamp, eventName, errorCode, errorMessage
            | filter eventSource = "eks.amazonaws.com" and ispresent(errorCode)
            | sort @timestamp desc
            | limit 20
          EOT
          region = data.aws_region.current.name
          title  = "EKS API Errors"
        }
      },
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.cloudtrail.name}'
            | fields @timestamp, eventName, requestParameters.nodegroupName
            | filter eventName in ["CreateNodegroup", "DeleteNodegroup", "UpdateNodegroupConfig"]
            | sort @timestamp desc
            | limit 20
          EOT
          region = data.aws_region.current.name
          title  = "Node Group Operations"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
