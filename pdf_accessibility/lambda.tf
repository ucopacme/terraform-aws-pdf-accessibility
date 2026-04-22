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

# ─── PDF Merger Lambda (Java, built by CodeBuild) ─────────────────────────

resource "aws_s3_bucket" "lambda_artifacts" {
  bucket_prefix = "pdf-accessibility-${var.environment}-lambda-"
  force_destroy = true

  tags = {
    Name = "pdf-accessibility-${var.environment}-lambda-artifacts"
  }
}

resource "aws_codebuild_project" "pdf_merger_builder" {
  name         = "pdf-accessibility-${var.environment}-pdf-merger-builder"
  description  = "Builds the PDF Merger Java Lambda JAR and uploads to S3"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.lambda_artifacts.id
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        install = {
          "runtime-versions" = { java = "corretto21" }
        }
        build = {
          commands = [
            "echo Building PDF Merger Lambda JAR...",
            "cd lambda/pdf-merger-lambda/PDFMergerLambda",
            "mvn clean package -q",
            "echo Uploading JAR to S3...",
            "aws s3 cp target/PDFMergerLambda-1.0-SNAPSHOT.jar s3://$ARTIFACT_BUCKET/pdf-merger.jar",
          ]
        }
      }
    })
  }

  source_version = var.github_branch

  tags = { Name = "pdf-accessibility-${var.environment}-pdf-merger-builder" }
}

# Add S3 permissions to CodeBuild role for artifact upload
resource "aws_iam_role_policy" "codebuild_s3_artifacts" {
  name = "s3-artifact-upload"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = ["${aws_s3_bucket.lambda_artifacts.arn}/*"]
    }]
  })
}

resource "null_resource" "trigger_merger_build" {
  triggers = {
    codebuild_project = aws_codebuild_project.pdf_merger_builder.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SCRIPT
      set -e
      PROJECT="${aws_codebuild_project.pdf_merger_builder.name}"
      REGION="${var.aws_region}"
      echo "Starting PDF Merger build: $PROJECT"
      BUILD_ID=$(aws codebuild start-build --project-name "$PROJECT" --region "$REGION" --query 'build.id' --output text)
      echo "Build started: $BUILD_ID"
      while true; do
        STATUS=$(aws codebuild batch-get-builds --ids "$BUILD_ID" --region "$REGION" --query 'builds[0].buildStatus' --output text)
        case "$STATUS" in
          SUCCEEDED) echo "Build SUCCEEDED"; break ;;
          FAILED|FAULT|STOPPED|TIMED_OUT) echo "Build failed: $STATUS"; exit 1 ;;
          IN_PROGRESS) echo -n "."; sleep 10 ;;
          *) sleep 5 ;;
        esac
      done
    SCRIPT
  }

  depends_on = [aws_codebuild_project.pdf_merger_builder, aws_s3_bucket.lambda_artifacts]
}

resource "aws_lambda_function" "pdf_merger" {
  function_name = "pdf-accessibility-${var.environment}-pdf-merger"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "com.example.App::handleRequest"
  runtime       = "java21"
  s3_bucket     = aws_s3_bucket.lambda_artifacts.id
  s3_key        = "pdf-merger.jar"
  timeout       = 900
  memory_size   = 1024

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.pdf_processing.id
    }
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf-merger-lambda"
  }

  depends_on = [null_resource.trigger_merger_build]
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
