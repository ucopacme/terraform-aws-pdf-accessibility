# ═══════════════════════════════════════════════════════════════════════════
# CloudWatch Dashboard
# ═══════════════════════════════════════════════════════════════════════════

locals {
  splitter_log_group  = "/aws/lambda/${aws_lambda_function.pdf_splitter.function_name}"
  merger_log_group    = "/aws/lambda/${aws_lambda_function.pdf_merger.function_name}"
  autotag_log_group   = aws_cloudwatch_log_group.adobe_autotag.name
  alt_text_log_group  = aws_cloudwatch_log_group.alt_text_generator.name
  step_fn_log_group   = aws_cloudwatch_log_group.step_functions.name
}

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
          query  = "SOURCE '${local.splitter_log_group}' | SOURCE '${local.merger_log_group}' | SOURCE '${local.autotag_log_group}' | SOURCE '${local.alt_text_log_group}' | fields @timestamp, @message | parse @message \"File: *, Status: *\" as file, status | stats latest(status) as latestStatus by file | sort file asc"
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
          query  = "SOURCE '${local.splitter_log_group}' | fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          query  = "SOURCE '${local.step_fn_log_group}' | fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          query  = "SOURCE '${local.autotag_log_group}' | fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          query  = "SOURCE '${local.alt_text_log_group}' | fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
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
          query  = "SOURCE '${local.merger_log_group}' | fields @timestamp, @message | filter @message like /filename/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
