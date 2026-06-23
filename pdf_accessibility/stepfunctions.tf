# ═══════════════════════════════════════════════════════════════════════════
# Step Functions State Machine
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/pdf-accessibility-remediation-workflow"
  retention_in_days = 14

  tags = {
    Name = "pdf-accessibility-${var.environment}-remediation-workflow-logs"
  }
}

# ─── Step Functions IAM Role ──────────────────────────────────────────────

resource "aws_iam_role" "step_functions" {
  name = "pdf-accessibility-${var.environment}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-step-functions-role"
  }
}

resource "aws_iam_role_policy" "step_functions_permissions" {
  name = "step-functions-permissions"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambda"
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.pdf_merger.arn,
          "${aws_lambda_function.pdf_merger.arn}:*",
          aws_lambda_function.title_generator.arn,
          "${aws_lambda_function.title_generator.arn}:*",
          aws_lambda_function.pre_remediation_checker.arn,
          "${aws_lambda_function.pre_remediation_checker.arn}:*",
          aws_lambda_function.post_remediation_checker.arn,
          "${aws_lambda_function.post_remediation_checker.arn}:*",
          "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:pdf-accessibility-${var.environment}-error-marker",
        ]
      },
      {
        Sid    = "RunEcsTasks"
        Effect = "Allow"
        Action = ["ecs:RunTask", "ecs:StopTask", "ecs:DescribeTasks"]
        Resource = [
          aws_ecs_task_definition.adobe_autotag.arn,
          "${replace(aws_ecs_task_definition.adobe_autotag.arn, "/:\\d+$/", "")}:*",
          aws_ecs_task_definition.alt_text_generator.arn,
          "${replace(aws_ecs_task_definition.alt_text_generator.arn, "/:\\d+$/", "")}:*",
        ]
      },
      {
        Sid      = "PassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.ecs_task_execution.arn, aws_iam_role.ecs_task.arn]
      },
      {
        Sid    = "EventsAccess"
        Effect = "Allow"
        Action = ["events:PutTargets", "events:PutRule", "events:DescribeRule"]
        Resource = [
          "arn:aws:events:${var.aws_region}:${var.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies", "logs:DescribeLogGroups"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# ─── State Machine Definition (matches working CDK deployment) ────────────

resource "aws_sfn_state_machine" "pdf_remediation" {
  name     = "pdf-accessibility-${var.environment}-remediation-workflow"
  role_arn = aws_iam_role.step_functions.arn

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = false
    level                  = "ERROR"
  }

  definition = jsonencode({
    TimeoutSeconds = 9000
    StartAt        = "ParallelAccessibilityWorkflow"
    States = {
      ParallelAccessibilityWorkflow = {
        Type       = "Parallel"
        ResultPath = "$.ParallelResults"
        Next       = "WriteSuccessMarker"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "WriteErrorMarker"
        }]
        Branches = [
          {
            StartAt = "ProcessPdfChunksInParallel"
            States = {
              ProcessPdfChunksInParallel = {
                Type           = "Map"
                MaxConcurrency = 100
                ItemsPath      = "$.chunks"
                ResultPath     = "$.MapResults"
                Next           = "MergePdfChunks"
                Iterator = {
                  StartAt = "RunAdobeAutotagTask"
                  States = {
                    RunAdobeAutotagTask = {
                      Type       = "Task"
                      Resource   = "arn:aws:states:::ecs:runTask.sync"
                      ResultPath = "$.AdobeTaskResult"
                      Next       = "RunAltTextGenerationTask"
                      Parameters = {
                        Cluster         = aws_ecs_cluster.pdf_remediation.arn
                        TaskDefinition  = aws_ecs_task_definition.adobe_autotag.arn
                        LaunchType      = "FARGATE"
                        PlatformVersion = "LATEST"
                        PropagateTags   = "TASK_DEFINITION"
                        NetworkConfiguration = {
                          AwsvpcConfiguration = {
                            Subnets        = aws_subnet.private[*].id
                            SecurityGroups = [aws_security_group.ecs_tasks.id]
                          }
                        }
                        Overrides = {
                          ContainerOverrides = [{
                            Name = "adobe-autotag-container"
                            Environment = [
                              { Name = "S3_BUCKET_NAME", "Value.$" = "$.s3_bucket" },
                              { Name = "S3_FILE_KEY", "Value.$" = "$.s3_key" },
                              { Name = "S3_CHUNK_KEY", "Value.$" = "$.chunk_key" },
                              { Name = "AWS_REGION", Value = var.aws_region }
                            ]
                          }]
                        }
                      }
                    }
                    RunAltTextGenerationTask = {
                      Type     = "Task"
                      Resource = "arn:aws:states:::ecs:runTask.sync"
                      End      = true
                      Parameters = {
                        Cluster         = aws_ecs_cluster.pdf_remediation.arn
                        TaskDefinition  = aws_ecs_task_definition.alt_text_generator.arn
                        LaunchType      = "FARGATE"
                        PlatformVersion = "LATEST"
                        PropagateTags   = "TASK_DEFINITION"
                        NetworkConfiguration = {
                          AwsvpcConfiguration = {
                            Subnets        = aws_subnet.private[*].id
                            SecurityGroups = [aws_security_group.ecs_tasks.id]
                          }
                        }
                        Overrides = {
                          ContainerOverrides = [{
                            Name = "alt-text-llm-container"
                            Environment = [
                              { Name = "S3_BUCKET_NAME", "Value.$" = "$.s3_bucket" },
                              { Name = "S3_FILE_KEY", "Value.$" = "$.s3_key" },
                              { Name = "AWS_REGION", Value = var.aws_region }
                            ]
                          }]
                        }
                      }
                    }
                  }
                }
              }
              MergePdfChunks = {
                Type       = "Task"
                Resource   = "arn:aws:states:::lambda:invoke"
                OutputPath = "$.Payload"
                Next       = "GenerateAccessibleTitle"
                Retry = [{
                  ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
                  IntervalSeconds = 2
                  MaxAttempts     = 6
                  BackoffRate     = 2
                }]
                Parameters = {
                  FunctionName = aws_lambda_function.pdf_merger.arn
                  Payload = {
                    "fileNames.$" = "$.chunks[*].s3_key"
                  }
                }
              }
              GenerateAccessibleTitle = {
                Type     = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Next     = "AuditPostRemediationAccessibility"
                Retry = [{
                  ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
                  IntervalSeconds = 2
                  MaxAttempts     = 6
                  BackoffRate     = 2
                }]
                Parameters = {
                  FunctionName = aws_lambda_function.title_generator.arn
                  Payload = {
                    "Payload.$" = "$"
                  }
                }
              }
              AuditPostRemediationAccessibility = {
                Type       = "Task"
                Resource   = "arn:aws:states:::lambda:invoke"
                OutputPath = "$.Payload"
                End        = true
                Retry = [{
                  ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
                  IntervalSeconds = 2
                  MaxAttempts     = 6
                  BackoffRate     = 2
                }]
                Parameters = {
                  FunctionName = aws_lambda_function.post_remediation_checker.arn
                  "Payload.$"  = "$"
                }
              }
            }
          },
          {
            StartAt = "AuditPreRemediationAccessibility"
            States = {
              AuditPreRemediationAccessibility = {
                Type       = "Task"
                Resource   = "arn:aws:states:::lambda:invoke"
                OutputPath = "$.Payload"
                End        = true
                Retry = [{
                  ErrorEquals     = ["Lambda.ClientExecutionTimeoutException", "Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
                  IntervalSeconds = 2
                  MaxAttempts     = 6
                  BackoffRate     = 2
                }]
                Parameters = {
                  FunctionName = aws_lambda_function.pre_remediation_checker.arn
                  "Payload.$"  = "$"
                }
              }
            }
          }
        ]
      }
      WriteErrorMarker = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:pdf-accessibility-${var.environment}-error-marker"
          Payload = {
            "s3_bucket.$" = "$.s3_bucket"
            "file_key.$"  = "$.file_key"
            "error.$"     = "$.error"
          }
        }
        Next = "FailExecution"
      }
      WriteSuccessMarker = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        ResultPath = "$.successMarkerResult"
        Parameters = {
          FunctionName = "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:pdf-accessibility-${var.environment}-error-marker"
          Payload = {
            "s3_bucket.$" = "$.s3_bucket"
            "file_key.$"  = "$.file_key"
            "status"      = "SUCCESS"
          }
        }
        Next = "SuccessEnd"
      }
      FailExecution = {
        Type  = "Fail"
        Error = "RemediationFailed"
        Cause = "One or more steps in the PDF remediation pipeline failed."
      }
      SuccessEnd = {
        Type = "Succeed"
      }
    }
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-remediation-workflow"
  }
}
