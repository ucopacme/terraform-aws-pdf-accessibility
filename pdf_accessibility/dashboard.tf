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
          title  = "Failed Files Summary"
          region = var.aws_region
          query  = "SOURCE '${local.splitter_log_group}' | SOURCE '${local.autotag_log_group}' | SOURCE '${local.alt_text_log_group}' | SOURCE '${local.merger_log_group}' | fields @timestamp, @message | parse @message \"File: *, Status: *\" as file, status | filter status like /(?i)fail|error/ | stats latest(status) as lastStatus, latest(@timestamp) as lastSeen by file | sort lastSeen desc"
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
          title  = "All Errors — ECS Containers"
          region = var.aws_region
          query  = "SOURCE '${local.autotag_log_group}' | SOURCE '${local.alt_text_log_group}' | fields @timestamp, @message | filter @message like /- ERROR -|error:/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Step Function Executions"
          region = var.aws_region
          query  = "SOURCE '${local.step_fn_log_group}' | fields @timestamp, @message | filter @message like /ExecutionSucceeded|ExecutionFailed|ExecutionStarted|ExecutionTimedOut/ | sort @timestamp desc | limit 30"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors & Timeouts"
          region = var.aws_region
          query  = "SOURCE '${local.splitter_log_group}' | SOURCE '${local.merger_log_group}' | SOURCE '/aws/lambda/${aws_lambda_function.title_generator.function_name}' | SOURCE '/aws/lambda/${aws_lambda_function.pre_remediation_checker.function_name}' | SOURCE '/aws/lambda/${aws_lambda_function.post_remediation_checker.function_name}' | fields @timestamp, @message | filter @message like /ERROR|Task timed out|Exception|Traceback/ | sort @timestamp desc | limit 30"
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
          title  = "File Status"
          region = var.aws_region
          query  = "SOURCE '${local.splitter_log_group}' | SOURCE '${local.merger_log_group}' | SOURCE '${local.autotag_log_group}' | SOURCE '${local.alt_text_log_group}' | fields @timestamp, @message | parse @message \"File: *, Status: *\" as file, status | stats latest(status) as latestStatus by file | sort file asc"
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
          title  = "Split PDF Lambda Logs"
          region = var.aws_region
          query  = "SOURCE '${local.splitter_log_group}' | fields @timestamp, @message | filter @message like /(?i)filename/ | sort @timestamp desc | limit 50"
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
          title  = "Step Function Execution Logs"
          region = var.aws_region
          query  = "SOURCE '${local.step_fn_log_group}' | fields @timestamp, @message | filter @message like /(?i)filename/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 36
        width  = 24
        height = 6
        properties = {
          title  = "Adobe Autotag Processing Logs"
          region = var.aws_region
          query  = "SOURCE '${local.autotag_log_group}' | fields @timestamp, @message | filter @message like /(?i)filename/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 42
        width  = 24
        height = 6
        properties = {
          title  = "Alt Text Generation Logs"
          region = var.aws_region
          query  = "SOURCE '${local.alt_text_log_group}' | fields @timestamp, @message | filter @message like /(?i)filename/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 48
        width  = 24
        height = 6
        properties = {
          title  = "PDF Merger Lambda Logs"
          region = var.aws_region
          query  = "SOURCE '${local.merger_log_group}' | fields @timestamp, @message | filter @message like /(?i)filename/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
