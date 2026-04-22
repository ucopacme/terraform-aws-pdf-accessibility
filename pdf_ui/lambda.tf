# ═══════════════════════════════════════════════════════════════════════════
# Lambda Functions for UI Backend
# ═══════════════════════════════════════════════════════════════════════════

# ─── Package Lambda source code ───────────────────────────────────────────

data "archive_file" "post_confirmation" {
  type        = "zip"
  source_dir  = "${var.lambda_source_base_dir}/postConfirmation"
  output_path = "${path.module}/builds/postConfirmation.zip"
}

data "archive_file" "update_attributes" {
  type        = "zip"
  source_dir  = "${var.lambda_source_base_dir}/updateAttributes"
  output_path = "${path.module}/builds/updateAttributes.zip"
}

data "archive_file" "check_or_increment_quota" {
  type        = "zip"
  source_dir  = "${var.lambda_source_base_dir}/checkOrIncrementQuota"
  output_path = "${path.module}/builds/checkOrIncrementQuota.zip"
}

data "archive_file" "update_attributes_groups" {
  type        = "zip"
  source_dir  = "${var.lambda_source_base_dir}/UpdateAttributesGroups"
  output_path = "${path.module}/builds/UpdateAttributesGroups.zip"
}

data "archive_file" "pre_sign_up" {
  type        = "zip"
  source_dir  = "${var.lambda_source_base_dir}/preSignUp"
  output_path = "${path.module}/builds/preSignUp.zip"
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
  function_name    = "pdf-accessibility-${var.environment}-post-confirmation"
  role             = aws_iam_role.post_confirmation.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.post_confirmation.output_path
  source_code_hash = data.archive_file.post_confirmation.output_base64sha256

  environment {
    variables = {
      DEFAULT_GROUP_NAME = local.default_group
      AMAZON_GROUP_NAME  = local.amazon_group
      ADMIN_GROUP_NAME   = local.admin_group
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-post-confirmation" }
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
  function_name    = "pdf-accessibility-${var.environment}-update-attributes"
  role             = aws_iam_role.post_confirmation.arn # Reuses same role
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.update_attributes.output_path
  source_code_hash = data.archive_file.update_attributes.output_base64sha256

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pdf_ui.id
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-update-attributes" }
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
  function_name    = "pdf-accessibility-${var.environment}-check-or-increment-quota"
  role             = aws_iam_role.check_upload_quota.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.check_or_increment_quota.output_path
  source_code_hash = data.archive_file.check_or_increment_quota.output_base64sha256

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pdf_ui.id
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-check-or-increment-quota" }
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
  function_name    = "pdf-accessibility-${var.environment}-update-attrs-groups"
  role             = aws_iam_role.update_attributes_groups.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  filename         = data.archive_file.update_attributes_groups.output_path
  source_code_hash = data.archive_file.update_attributes_groups.output_base64sha256

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pdf_ui.id
    }
  }

  tags = { Name = "pdf-accessibility-${var.environment}-update-attrs-groups" }
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
  function_name    = "pdf-accessibility-${var.environment}-pre-sign-up"
  role             = aws_iam_role.pre_sign_up.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.pre_sign_up.output_path
  source_code_hash = data.archive_file.pre_sign_up.output_base64sha256

  tags = { Name = "pdf-accessibility-${var.environment}-pre-sign-up" }
}

resource "aws_lambda_permission" "cognito_pre_sign_up" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_sign_up.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pdf_ui.arn
}
