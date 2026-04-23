# ═══════════════════════════════════════════════════════════════════════════
# Lambda Functions
# ═══════════════════════════════════════════════════════════════════════════

# ─── Shared Lambda IAM Role ───────────────────────────────────────────────

resource "aws_iam_role" "lambda_execution" {
  name = "pdf-accessibility-${var.environment}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-lambda-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "pdf-accessibility-lambda-permissions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.pdf_processing.arn, "${aws_s3_bucket.pdf_processing.arn}/*"]
      },
      {
        Sid      = "StepFunctionsAccess"
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = [aws_sfn_state_machine.pdf_remediation.arn]
      },
      {
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
      },
      {
        Sid      = "BedrockAccess"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["*"]
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = ["arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:/myapp/*"]
      }
    ]
  })
}

# ─── ECR Repositories for Docker-based Lambdas ───────────────────────────

resource "aws_ecr_repository" "pdf_splitter" {
  name                 = "pdf-accessibility/pdf-splitter"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = { Name = "pdf-accessibility-pdf-splitter-ecr" }
}

resource "aws_ecr_repository" "title_generator" {
  name                 = "pdf-accessibility/title-generator"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = { Name = "pdf-accessibility-title-generator-ecr" }
}

resource "aws_ecr_repository" "pre_remediation_checker" {
  name                 = "pdf-accessibility/pre-remediation-checker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = { Name = "pdf-accessibility-pre-remediation-checker-ecr" }
}

resource "aws_ecr_repository" "post_remediation_checker" {
  name                 = "pdf-accessibility/post-remediation-checker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = { Name = "pdf-accessibility-post-remediation-checker-ecr" }
}

# ─── Build Docker Images for Lambda Functions (via CodeBuild — see codebuild.tf) ──

# ─── PDF Splitter Lambda (Docker-based, triggered by S3) ──────────────────

resource "aws_lambda_function" "pdf_splitter" {
  function_name = "pdf-accessibility-${var.environment}-pdf-splitter"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.pdf_splitter.repository_url}:latest"
  timeout       = 900
  memory_size   = 1024

  image_config {
    command = ["main.lambda_handler"]
  }

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.pdf_remediation.arn
    }
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf-splitter-lambda"
  }

  depends_on = [null_resource.trigger_image_build]
}

resource "aws_lambda_permission" "s3_invoke_splitter" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_splitter.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.pdf_processing.arn
}

resource "aws_s3_bucket_notification" "pdf_upload" {
  bucket = aws_s3_bucket.pdf_processing.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdf_splitter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "pdf/"
    filter_suffix       = ".pdf"
  }

  depends_on = [
    aws_lambda_permission.s3_invoke_splitter,
    aws_s3_bucket_policy.enforce_ssl,
  ]
}

# ─── PDF Merger Lambda (Java, pre-built JAR) ──────────────────────────────

resource "aws_lambda_function" "pdf_merger" {
  function_name    = "pdf-accessibility-${var.environment}-pdf-merger"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "com.example.App::handleRequest"
  runtime          = "java21"
  filename         = var.pdf_merger_jar_path
  source_code_hash = filebase64sha256(var.pdf_merger_jar_path)
  timeout          = 900
  memory_size      = 1024

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.pdf_processing.id
    }
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf-merger-lambda"
  }
}

# ─── Title Generator Lambda (Docker-based) ────────────────────────────────

resource "aws_lambda_function" "title_generator" {
  function_name = "pdf-accessibility-${var.environment}-title-generator"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.title_generator.repository_url}:latest"
  timeout       = 900
  memory_size   = 1024

  image_config {
    command = ["title_generator.lambda_handler"]
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-title-generator-lambda"
  }

  depends_on = [null_resource.trigger_image_build]
}

# ─── Pre-Remediation Accessibility Checker Lambda (Docker-based) ──────────

resource "aws_lambda_function" "pre_remediation_checker" {
  function_name = "pdf-accessibility-${var.environment}-pre-remediation-checker"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.pre_remediation_checker.repository_url}:latest"
  timeout       = 900
  memory_size   = 512

  image_config {
    command = ["main.lambda_handler"]
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-pre-remediation-checker-lambda"
  }

  depends_on = [null_resource.trigger_image_build]
}

# ─── Post-Remediation Accessibility Checker Lambda (Docker-based) ─────────

resource "aws_lambda_function" "post_remediation_checker" {
  function_name = "pdf-accessibility-${var.environment}-post-remediation-checker"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.post_remediation_checker.repository_url}:latest"
  timeout       = 900
  memory_size   = 512

  image_config {
    command = ["main.lambda_handler"]
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-post-remediation-checker-lambda"
  }

  depends_on = [null_resource.trigger_image_build]
}
