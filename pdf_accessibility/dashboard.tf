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
          source = join(", ", [
            aws_cloudwatch_log_group.adobe_autotag.name,
            aws_cloudwatch_log_group.alt_text_generator.name,
            "/aws/lambda/${aws_lambda_function.pdf_splitter.function_name}",
            "/aws/lambda/${aws_lambda_function.pdf_merger.function_name}",
          ])
          query  = "fields @timestamp, @message | parse @message \"File: *, Status: *\" as file, status | stats latest(status) as latestStatus by file | sort file asc"
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
          source = "/aws/lambda/${aws_lambda_function.pdf_splitter.function_name}"
          query  = "fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          source = aws_cloudwatch_log_group.step_functions.name
          query  = "fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          source = aws_cloudwatch_log_group.adobe_autotag.name
          query  = "fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          source = aws_cloudwatch_log_group.alt_text_generator.name
          query  = "fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          source = "/aws/lambda/${aws_lambda_function.pdf_merger.function_name}"
          query  = "fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
