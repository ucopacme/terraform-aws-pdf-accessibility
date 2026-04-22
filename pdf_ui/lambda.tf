# ═══════════════════════════════════════════════════════════════════════════
# Lambda Functions for UI Backend
# All Lambda code is pulled from GitHub via CodeBuild, zipped, and stored in S3
# ═══════════════════════════════════════════════════════════════════════════

# ─── S3 bucket for Lambda deployment packages ─────────────────────────────

resource "aws_s3_bucket" "lambda_artifacts" {
  bucket_prefix = "pdf-accessibility-${var.environment}-ui-lambda-"
  force_destroy = true

  tags = {
    Name = "pdf-accessibility-${var.environment}-ui-lambda-artifacts"
  }
}

# ─── CodeBuild project to package UI Lambdas from GitHub ──────────────────

resource "aws_iam_role" "codebuild_lambda" {
  name = "pdf-accessibility-${var.environment}-ui-lambda-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-ui-lambda-codebuild-role" }
}

resource "aws_iam_role_policy" "codebuild_lambda" {
  name = "codebuild-lambda-permissions"
  role = aws_iam_role.codebuild_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/codebuild/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = ["${aws_s3_bucket.lambda_artifacts.arn}/*"]
      }
    ]
  })
}

resource "aws_codebuild_project" "ui_lambda_packager" {
  name         = "pdf-accessibility-${var.environment}-ui-lambda-packager"
  description  = "Packages UI Lambda functions from GitHub and uploads zips to S3"
  service_role = aws_iam_role.codebuild_lambda.arn

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
    location        = var.ui_github_repo_url
    git_clone_depth = 1
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        build = {
          commands = [
            "echo Packaging UI Lambda functions...",
            "cd cdk_backend/lambda",
            "for dir in postConfirmation updateAttributes checkOrIncrementQuota UpdateAttributesGroups preSignUp; do echo \"Zipping $dir...\"; cd $dir; zip -r /tmp/$dir.zip .; aws s3 cp /tmp/$dir.zip s3://$ARTIFACT_BUCKET/$dir.zip; cd ..; done",
            "echo All Lambda packages uploaded to S3",
          ]
        }
      }
    })
  }

  source_version = var.ui_github_branch

  tags = { Name = "pdf-accessibility-${var.environment}-ui-lambda-packager" }
}

resource "null_resource" "trigger_ui_lambda_build" {
  triggers = {
    codebuild_project = aws_codebuild_project.ui_lambda_packager.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SCRIPT
      set -e
      PROJECT="${aws_codebuild_project.ui_lambda_packager.name}"
      REGION="${var.aws_region}"
      echo "Starting UI Lambda packager: $PROJECT"
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

  depends_on = [aws_codebuild_project.ui_lambda_packager, aws_s3_bucket.lambda_artifacts]
}

# ─── Post Confirmation Lambda ─────────────────────────────────────────────

resource "aws_iam_role" "post_confirmation" {
  name = "pdf-accessibility-${var.environment}-post-confirmation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-post-confirmation-role" }
}

resource "aws_iam_role_policy_attachment" "post_confirmation_basic" {
  role       = aws_iam_role.post_confirmation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "post_confirmation_cognito" {
  name = "cognito-access"
  role = aws_iam_role.post_confirmation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminAddUserToGroup"
      ]
      Resource = [aws_cognito_user_pool.pdf_ui.arn]
    }]
  })
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = "pdf-accessibility-${var.environment}-post-confirmation"
  role          = aws_iam_role.post_confirmation.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  s3_bucket     = aws_s3_bucket.lambda_artifacts.id
  s3_key        = "postConfirmation.zip"

  environment {
    variables = {
      DEFAULT_GROUP_NAME = local.default_group
      AMAZON_GROUP_NAME  = local.amazon_group
      ADMIN_GROUP_NAME   = local.admin_group
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-post-confirmation" }

  depends_on = [null_resource.trigger_ui_lambda_build]
}

resource "aws_lambda_permission" "cognito_post_confirmation" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pdf_ui.arn
}

# ─── Update Attributes Lambda ─────────────────────────────────────────────

resource "aws_lambda_function" "update_attributes" {
  function_name = "pdf-accessibility-${var.environment}-update-attributes"
  role          = aws_iam_role.post_confirmation.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  s3_bucket     = aws_s3_bucket.lambda_artifacts.id
  s3_key        = "updateAttributes.zip"

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pdf_ui.id
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-update-attributes" }

  depends_on = [null_resource.trigger_ui_lambda_build]
}

# ─── Check/Increment Quota Lambda ─────────────────────────────────────────

resource "aws_iam_role" "check_upload_quota" {
  name = "pdf-accessibility-${var.environment}-check-upload-quota-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-check-upload-quota-role" }
}

resource "aws_iam_role_policy_attachment" "check_upload_quota_basic" {
  role       = aws_iam_role.check_upload_quota.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "check_upload_quota_cognito" {
  name = "cognito-access"
  role = aws_iam_role.check_upload_quota.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminUpdateUserAttributes"
      ]
      Resource = [aws_cognito_user_pool.pdf_ui.arn]
    }]
  })
}

resource "aws_lambda_function" "check_or_increment_quota" {
  function_name = "pdf-accessibility-${var.environment}-check-or-increment-quota"
  role          = aws_iam_role.check_upload_quota.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  s3_bucket     = aws_s3_bucket.lambda_artifacts.id
  s3_key        = "checkOrIncrementQuota.zip"

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pdf_ui.id
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-check-or-increment-quota" }

  depends_on = [null_resource.trigger_ui_lambda_build]
}

# ─── Update Attributes Groups Lambda (EventBridge triggered) ──────────────

resource "aws_iam_role" "update_attributes_groups" {
  name = "pdf-accessibility-${var.environment}-update-attrs-groups-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-update-attrs-groups-role" }
}

resource "aws_iam_role_policy" "update_attributes_groups_permissions" {
  name = "cognito-and-logs"
  role = aws_iam_role.update_attributes_groups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:ListUsersInGroup",
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminListGroupsForUser",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = [
        aws_cognito_user_pool.pdf_ui.arn,
        "${aws_cognito_user_pool.pdf_ui.arn}/*"
      ]
    }]
  })
}

resource "aws_lambda_function" "update_attributes_groups" {
  function_name = "pdf-accessibility-${var.environment}-update-attrs-groups"
  role          = aws_iam_role.update_attributes_groups.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  s3_bucket     = aws_s3_bucket.lambda_artifacts.id
  s3_key        = "UpdateAttributesGroups.zip"

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pdf_ui.id
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-update-attrs-groups" }

  depends_on = [null_resource.trigger_ui_lambda_build]
}

resource "aws_lambda_permission" "eventbridge_invoke_update_groups" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_attributes_groups.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cognito_group_change.arn
}

# ─── Pre Sign Up Lambda ───────────────────────────────────────────────────

resource "aws_iam_role" "pre_sign_up" {
  name = "pdf-accessibility-${var.environment}-pre-sign-up-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "pdf-accessibility-${var.environment}-pre-sign-up-role" }
}

resource "aws_iam_role_policy_attachment" "pre_sign_up_basic" {
  role       = aws_iam_role.pre_sign_up.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "pre_sign_up_cognito" {
  name = "cognito-access"
  role = aws_iam_role.pre_sign_up.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:ListUsers",
        "cognito-idp:AdminDeleteUser"
      ]
      Resource = [aws_cognito_user_pool.pdf_ui.arn]
    }]
  })
}

resource "aws_lambda_function" "pre_sign_up" {
  function_name = "pdf-accessibility-${var.environment}-pre-sign-up"
  role          = aws_iam_role.pre_sign_up.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  s3_bucket     = aws_s3_bucket.lambda_artifacts.id
  s3_key        = "preSignUp.zip"

  tags = { Name = "pdf-accessibility-${var.environment}-pre-sign-up" }

  depends_on = [null_resource.trigger_ui_lambda_build]
}

resource "aws_lambda_permission" "cognito_pre_sign_up" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_sign_up.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pdf_ui.arn
}
