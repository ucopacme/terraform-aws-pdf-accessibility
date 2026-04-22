# ═══════════════════════════════════════════════════════════════════════════
# CodeBuild - Single project that builds all Docker images from GitHub
# ═══════════════════════════════════════════════════════════════════════════

variable "github_repo_url" {
  description = "GitHub repository URL for PDF_Accessibility backend"
  type        = string
  default     = "https://github.com/ucopacme/PDF_Accessibility.git"
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}

# ─── CodeBuild IAM Role ───────────────────────────────────────────────────

resource "aws_iam_role" "codebuild" {
  name = "pdf-accessibility-${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-codebuild-role" }
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
        Resource = [
          aws_ecr_repository.adobe_autotag.arn,
          aws_ecr_repository.alt_text_generator.arn,
          aws_ecr_repository.pdf_splitter.arn,
          aws_ecr_repository.title_generator.arn,
          aws_ecr_repository.pre_remediation_checker.arn,
          aws_ecr_repository.post_remediation_checker.arn,
        ]
      }
    ]
  })
}

# ─── CodeBuild Project (single project, builds all images) ───────────────

resource "aws_codebuild_project" "image_builder" {
  name         = "pdf-accessibility-${var.environment}-image-builder"
  description  = "Builds and pushes all PDF-to-PDF Docker images to ECR"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
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
      name  = "ADOBE_AUTOTAG_REPO"
      value = aws_ecr_repository.adobe_autotag.repository_url
    }

    environment_variable {
      name  = "ALT_TEXT_REPO"
      value = aws_ecr_repository.alt_text_generator.repository_url
    }

    environment_variable {
      name  = "PDF_SPLITTER_REPO"
      value = aws_ecr_repository.pdf_splitter.repository_url
    }

    environment_variable {
      name  = "TITLE_GENERATOR_REPO"
      value = aws_ecr_repository.title_generator.repository_url
    }

    environment_variable {
      name  = "PRE_CHECKER_REPO"
      value = aws_ecr_repository.pre_remediation_checker.repository_url
    }

    environment_variable {
      name  = "POST_CHECKER_REPO"
      value = aws_ecr_repository.post_remediation_checker.repository_url
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = yamlencode({
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
            "echo Building adobe-autotag image...",
            "docker build --platform linux/amd64 -t $ADOBE_AUTOTAG_REPO:latest adobe-autotag-container/",
            "echo Building alt-text-generator image...",
            "docker build --platform linux/amd64 -t $ALT_TEXT_REPO:latest alt-text-generator-container/",
            "echo Building Lambda images with /asset -> /var/task fix...",
            "echo 'ARG BASE_IMAGE' > /tmp/LambdaFix.Dockerfile",
            "echo 'FROM $${BASE_IMAGE}' >> /tmp/LambdaFix.Dockerfile",
            "echo 'RUN cp -a /asset/* /var/task/ 2>/dev/null || true' >> /tmp/LambdaFix.Dockerfile",
            "echo Building pdf-splitter image...",
            "docker build --platform linux/amd64 -t pdf-splitter-base:latest lambda/pdf-splitter-lambda/",
            "docker build --platform linux/amd64 -t $PDF_SPLITTER_REPO:latest --build-arg BASE_IMAGE=pdf-splitter-base:latest -f /tmp/LambdaFix.Dockerfile .",
            "echo Building title-generator image...",
            "docker build --platform linux/amd64 -t title-gen-base:latest lambda/title-generator-lambda/",
            "docker build --platform linux/amd64 -t $TITLE_GENERATOR_REPO:latest --build-arg BASE_IMAGE=title-gen-base:latest -f /tmp/LambdaFix.Dockerfile .",
            "echo Building pre-remediation-checker image...",
            "docker build --platform linux/amd64 -t pre-checker-base:latest lambda/pre-remediation-accessibility-checker/",
            "docker build --platform linux/amd64 -t $PRE_CHECKER_REPO:latest --build-arg BASE_IMAGE=pre-checker-base:latest -f /tmp/LambdaFix.Dockerfile .",
            "echo Building post-remediation-checker image...",
            "docker build --platform linux/amd64 -t post-checker-base:latest lambda/post-remediation-accessibility-checker/",
            "docker build --platform linux/amd64 -t $POST_CHECKER_REPO:latest --build-arg BASE_IMAGE=post-checker-base:latest -f /tmp/LambdaFix.Dockerfile .",
          ]
        }
        post_build = {
          commands = [
            "echo Pushing all images to ECR...",
            "docker push $ADOBE_AUTOTAG_REPO:latest",
            "docker push $ALT_TEXT_REPO:latest",
            "docker push $PDF_SPLITTER_REPO:latest",
            "docker push $TITLE_GENERATOR_REPO:latest",
            "docker push $PRE_CHECKER_REPO:latest",
            "docker push $POST_CHECKER_REPO:latest",
            "echo All images pushed successfully on $(date)",
          ]
        }
      }
    })
  }

  source_version = var.github_branch

  tags = { Name = "pdf-accessibility-${var.environment}-image-builder" }
}

# ─── Trigger CodeBuild and wait for completion ───────────────────────────

resource "null_resource" "trigger_image_build" {
  triggers = {
    # Re-trigger when ECR repos or CodeBuild project changes
    codebuild_project = aws_codebuild_project.image_builder.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SCRIPT
      set -e
      PROJECT="${aws_codebuild_project.image_builder.name}"
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

  depends_on = [aws_codebuild_project.image_builder]
}
