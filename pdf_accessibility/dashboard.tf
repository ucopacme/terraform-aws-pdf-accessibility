# ═══════════════════════════════════════════════════════════════════════════
# CloudWatch Dashboard
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_dashboard" "pdf_processing" {
  dashboard_name = "pdf-accessibility-${var.environment}-processing-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          title  = "File Status"
          region = var.aws_region
          query  = <<-EOT
            fields @timestamp, @message
            | parse @message "File: *, Status: *" as file, status
            | stats latest(status) as latestStatus by file
            | sort file asc
          EOT
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Split PDF Lambda Logs"
          region = var.aws_region
          query  = "fields @message | filter @message like /filename/"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Step Function Execution Logs"
          region = var.aws_region
          query  = "fields @message | filter @message like /filename/"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        properties = {
          title  = "Adobe Autotag Processing Logs"
          region = var.aws_region
          query  = "fields @message | filter @message like /filename/"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 24
        width  = 24
        height = 6
        properties = {
          title  = "Alt Text Generation Logs"
          region = var.aws_region
          query  = "fields @message | filter @message like /filename/"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 30
        width  = 24
        height = 6
        properties = {
          title  = "PDF Merger Lambda Logs"
          region = var.aws_region
          query  = "fields @message | filter @message like /filename/"
          view   = "table"
        }
      }
    ]
  })
}
