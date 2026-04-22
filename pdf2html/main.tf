# ═══════════════════════════════════════════════════════════════════════════
# PDF-to-HTML Remediation Module
# ═══════════════════════════════════════════════════════════════════════════

# ─── Bedrock Data Automation Project ──────────────────────────────────────
# Created automatically if bda_project_arn is not provided (matches old CDK behavior)

data "external" "bda_project" {
  count = var.bda_project_arn == "" ? 1 : 0

  program = ["bash", "-c", <<-SCRIPT
    set -e
    PROJECT_NAME="pdf-accessibility-${var.environment}-bda-project"
    REGION="${var.aws_region}"

    # Check if project already exists
    EXISTING=$(aws bedrock-data-automation list-data-automation-projects --region "$REGION" \
      --query "projects[?projectName=='$PROJECT_NAME'].projectArn" --output text 2>/dev/null || echo "")

    if [ -n "$EXISTING" ] && [ "$EXISTING" != "None" ]; then
      echo "{\"arn\": \"$EXISTING\"}"
      exit 0
    fi

    # Create new project
    RESPONSE=$(aws bedrock-data-automation create-data-automation-project \
      --project-name "$PROJECT_NAME" \
      --standard-output-configuration '{
        "document": {
          "extraction": {
            "granularity": { "types": ["DOCUMENT", "PAGE", "ELEMENT"] },
            "boundingBox": { "state": "ENABLED" }
          },
          "generativeField": { "state": "DISABLED" },
          "outputFormat": {
            "textFormat": { "types": ["HTML"] },
            "additionalFileFormat": { "state": "ENABLED" }
          }
        }
      }' \
      --region "$REGION" 2>&1)

    ARN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['projectArn'])" 2>/dev/null)
    if [ -z "$ARN" ]; then
      echo "{\"error\": \"Failed to create BDA project: $RESPONSE\"}" >&2
      exit 1
    fi
    echo "{\"arn\": \"$ARN\"}"
  SCRIPT
  ]
}

locals {
  bda_project_arn = var.bda_project_arn != "" ? var.bda_project_arn : data.external.bda_project[0].result["arn"]
}

# ─── S3 Bucket ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "pdf2html" {
  bucket = var.bucket_name

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf2html-bucket"
  }
}

resource "aws_s3_bucket_versioning" "pdf2html" {
  bucket = aws_s3_bucket.pdf2html.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create folder structure
resource "aws_s3_object" "uploads_folder" {
  bucket  = aws_s3_bucket.pdf2html.id
  key     = "uploads/"
  content = ""
}

resource "aws_s3_object" "output_folder" {
  bucket  = aws_s3_bucket.pdf2html.id
  key     = "output/"
  content = ""
}

resource "aws_s3_object" "remediated_folder" {
  bucket  = aws_s3_bucket.pdf2html.id
  key     = "remediated/"
  content = ""
}

# ─── ECR Repository ───────────────────────────────────────────────────────

resource "aws_ecr_repository" "pdf2html" {
  name                 = "pdf2html-lambda"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf2html-ecr"
  }
}

# Build and push Docker image via CodeBuild (GitHub source)

variable "github_repo_url" {
  description = "GitHub repository URL for PDF_Accessibility (contains pdf2html/)"
  type        = string
  default     = "https://github.com/ucopacme/PDF_Accessibility.git"
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}

resource "aws_iam_role" "codebuild" {
  name = "pdf-accessibility-${var.environment}-pdf2html-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-pdf2html-codebuild-role" }
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-permissions"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/codebuild/*"]
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [aws_ecr_repository.pdf2html.arn]
      }
    ]
  })
}

resource "aws_codebuild_project" "pdf2html" {
  name         = "pdf-accessibility-${var.environment}-build-pdf2html"
  description  = "Builds and pushes the pdf2html Lambda Docker image to ECR"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPO_URL"
      value = aws_ecr_repository.pdf2html.repository_url
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        pre_build = {
          commands = [
            "echo Logging in to Amazon ECR...",
            "aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com",
          ]
        }
        build = {
          commands = [
            "echo Building Docker image...",
            "docker build --platform linux/amd64 --no-cache -t $ECR_REPO_URL:latest pdf2html/",
          ]
        }
        post_build = {
          commands = [
            "echo Pushing Docker image to ECR...",
            "docker push $ECR_REPO_URL:latest",
            "echo Build completed on $(date)",
          ]
        }
      }
    })
  }

  source_version = var.github_branch

  tags = { Name = "pdf-accessibility-${var.environment}-build-pdf2html" }
}

resource "null_resource" "trigger_pdf2html_build" {
  triggers = {
    codebuild_project = aws_codebuild_project.pdf2html.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SCRIPT
      set -e
      PROJECT="${aws_codebuild_project.pdf2html.name}"
      REGION="${var.aws_region}"
      echo "Starting CodeBuild project: $PROJECT"
      BUILD_ID=$(aws codebuild start-build --project-name "$PROJECT" --region "$REGION" --query 'build.id' --output text)
      echo "Build started: $BUILD_ID"
      echo "Waiting for build to complete..."
      while true; do
        STATUS=$(aws codebuild batch-get-builds --ids "$BUILD_ID" --region "$REGION" --query 'builds[0].buildStatus' --output text)
        case "$STATUS" in
          SUCCEEDED)
            echo "Build $BUILD_ID SUCCEEDED"
            break
            ;;
          FAILED|FAULT|STOPPED|TIMED_OUT)
            echo "Build $BUILD_ID failed with status: $STATUS"
            exit 1
            ;;
          IN_PROGRESS)
            echo -n "."
            sleep 15
            ;;
          *)
            sleep 5
            ;;
        esac
      done
    SCRIPT
  }

  depends_on = [aws_codebuild_project.pdf2html]
}

# ─── Lambda IAM Role ──────────────────────────────────────────────────────

resource "aws_iam_role" "pdf2html_lambda" {
  name = "pdf-accessibility-${var.environment}-pdf2html-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf2html-lambda-role"
  }
}

resource "aws_iam_role_policy_attachment" "pdf2html_lambda_basic" {
  role       = aws_iam_role.pdf2html_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "pdf2html_lambda_permissions" {
  name = "pdf2html-permissions"
  role = aws_iam_role.pdf2html_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:DeleteObjects",
          "s3:ListObjects",
          "s3:ListObjectsV2",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:GetBucketPolicy"
        ]
        Resource = [
          aws_s3_bucket.pdf2html.arn,
          "${aws_s3_bucket.pdf2html.arn}/*"
        ]
      },
      {
        Sid    = "BedrockInvokeModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/us.amazon.nova-lite-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/us.amazon.nova-pro-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-pro-v1:0"
        ]
      },
      {
        Sid    = "BedrockDataAutomation"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeDataAutomationAsync",
          "bedrock:GetDataAutomationStatus",
          "bedrock:GetDataAutomationProject"
        ]
        Resource = [
          local.bda_project_arn,
          "arn:aws:bedrock:${var.aws_region}:${var.account_id}:data-automation-invocation/*"
        ]
      },
      {
        Sid    = "BedrockDataAutomationProfile"
        Effect = "Allow"
        Action = ["bedrock:InvokeDataAutomationAsync"]
        Resource = [
          "arn:aws:bedrock:*:${var.account_id}:data-automation-profile/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/pdf-accessibility-${var.environment}-pdf2html-pipeline:*"
        ]
      }
    ]
  })
}

# ─── Lambda Function ──────────────────────────────────────────────────────

resource "aws_lambda_function" "pdf2html" {
  function_name = "pdf-accessibility-${var.environment}-pdf2html-pipeline"
  role          = aws_iam_role.pdf2html_lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.pdf2html.repository_url}:latest"
  timeout       = 900
  memory_size   = 1024

  environment {
    variables = {
      BDA_PROJECT_ARN            = local.bda_project_arn
      BDA_S3_BUCKET              = aws_s3_bucket.pdf2html.id
      BDA_OUTPUT_PREFIX          = "bda-processing"
      CLEANUP_INTERMEDIATE_FILES = "true"
    }
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-pdf2html-pipeline"
  }

  depends_on = [null_resource.trigger_pdf2html_build]
}

# ─── S3 Event Notification ────────────────────────────────────────────────

resource "aws_lambda_permission" "s3_invoke_pdf2html" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf2html.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.pdf2html.arn
}

resource "aws_s3_bucket_notification" "pdf2html_upload" {
  bucket = aws_s3_bucket.pdf2html.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdf2html.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.s3_invoke_pdf2html]
}
