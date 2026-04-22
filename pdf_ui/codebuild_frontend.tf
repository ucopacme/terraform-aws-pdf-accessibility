# ═══════════════════════════════════════════════════════════════════════════
# CodeBuild - Builds React frontend and deploys to Amplify
# ═══════════════════════════════════════════════════════════════════════════

variable "ui_github_repo_url" {
  description = "GitHub repository URL for PDF_accessability_UI"
  type        = string
  default     = "https://github.com/ucopacme/PDF_accessability_UI.git"
}

variable "ui_github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}

# ─── CodeBuild IAM Role ───────────────────────────────────────────────────

resource "aws_iam_role" "codebuild_frontend" {
  name = "pdf-accessibility-${var.environment}-frontend-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-frontend-codebuild-role" }
}

resource "aws_iam_role_policy" "codebuild_frontend" {
  name = "frontend-codebuild-permissions"
  role = aws_iam_role.codebuild_frontend.id

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
        Sid    = "AmplifyDeploy"
        Effect = "Allow"
        Action = [
          "amplify:CreateDeployment",
          "amplify:StartDeployment",
          "amplify:GetApp",
          "amplify:GetBranch"
        ]
        Resource = ["arn:aws:amplify:${var.aws_region}:${var.account_id}:apps/${aws_amplify_app.pdf_ui.id}/*"]
      }
    ]
  })
}

# ─── Frontend CodeBuild Project ───────────────────────────────────────────

resource "aws_codebuild_project" "frontend" {
  name         = "pdf-accessibility-${var.environment}-frontend-builder"
  description  = "Builds React frontend and deploys to Amplify"
  service_role = aws_iam_role.codebuild_frontend.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AMPLIFY_APP_ID"
      value = aws_amplify_app.pdf_ui.id
    }

    environment_variable {
      name  = "REACT_APP_USER_POOL_ID"
      value = aws_cognito_user_pool.pdf_ui.id
    }

    environment_variable {
      name  = "REACT_APP_USER_POOL_CLIENT_ID"
      value = aws_cognito_user_pool_client.pdf_ui.id
    }

    environment_variable {
      name  = "REACT_APP_USER_POOL_DOMAIN"
      value = local.domain_prefix
    }

    environment_variable {
      name  = "REACT_APP_IDENTITY_POOL_ID"
      value = aws_cognito_identity_pool.pdf_ui.id
    }

    environment_variable {
      name  = "REACT_APP_AMPLIFY_APP_URL"
      value = local.app_url
    }

    environment_variable {
      name  = "REACT_APP_UPDATE_FIRST_SIGN_IN_ENDPOINT"
      value = "${aws_api_gateway_stage.prod.invoke_url}/update-first-sign-in"
    }

    environment_variable {
      name  = "REACT_APP_CHECK_UPLOAD_QUOTA_ENDPOINT"
      value = "${aws_api_gateway_stage.prod.invoke_url}/upload-quota"
    }

    dynamic "environment_variable" {
      for_each = var.deploy_pdf2pdf ? [1] : []
      content {
        name  = "PDF_TO_PDF_BUCKET"
        value = var.pdf_to_pdf_bucket_name
      }
    }

    dynamic "environment_variable" {
      for_each = var.deploy_pdf2html ? [1] : []
      content {
        name  = "PDF_TO_HTML_BUCKET"
        value = var.pdf_to_html_bucket_name
      }
    }
  }

  source {
    type            = "GITHUB"
    location        = var.ui_github_repo_url
    git_clone_depth = 1
    buildspec       = "buildspec-frontend.yml"
  }

  source_version = var.ui_github_branch

  tags = { Name = "pdf-accessibility-${var.environment}-frontend-builder" }
}

# ─── Trigger frontend build and wait ─────────────────────────────────────

resource "null_resource" "trigger_frontend_build" {
  triggers = {
    codebuild_project = aws_codebuild_project.frontend.id
    # Re-trigger if any backend outputs change
    user_pool_id = aws_cognito_user_pool.pdf_ui.id
    api_url      = aws_api_gateway_stage.prod.invoke_url
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SCRIPT
      set -e
      PROJECT="${aws_codebuild_project.frontend.name}"
      REGION="${var.aws_region}"
      echo "Starting frontend CodeBuild project: $PROJECT"
      BUILD_ID=$(aws codebuild start-build --project-name "$PROJECT" --region "$REGION" --query 'build.id' --output text)
      echo "Build started: $BUILD_ID"
      echo "Waiting for frontend build to complete..."
      while true; do
        STATUS=$(aws codebuild batch-get-builds --ids "$BUILD_ID" --region "$REGION" --query 'builds[0].buildStatus' --output text)
        case "$STATUS" in
          SUCCEEDED)
            echo "Frontend build $BUILD_ID SUCCEEDED"
            break
            ;;
          FAILED|FAULT|STOPPED|TIMED_OUT)
            echo "Frontend build $BUILD_ID failed with status: $STATUS"
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

  depends_on = [
    aws_codebuild_project.frontend,
    aws_cognito_user_pool.pdf_ui,
    aws_cognito_user_pool_client.pdf_ui,
    aws_cognito_identity_pool.pdf_ui,
    aws_api_gateway_stage.prod,
    aws_amplify_app.pdf_ui,
  ]
}
