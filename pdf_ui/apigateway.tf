# ═══════════════════════════════════════════════════════════════════════════
# API Gateway
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_api_gateway_rest_api" "main" {
  name        = "pdf-accessibility-${var.environment}-api"
  description = "API to update Cognito user attributes (org, first_sign_in, country, state, city, total_file_uploaded)."

  tags = {
    Name = "pdf-accessibility-${var.environment}-api"
  }
}

# ─── Cognito Authorizer ───────────────────────────────────────────────────

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "CognitoUserPoolAuthorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.pdf_ui.arn]
  identity_source = "method.request.header.Authorization"
}

# ─── /update-first-sign-in Resource ───────────────────────────────────────

resource "aws_api_gateway_resource" "update_first_sign_in" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "update-first-sign-in"
}

resource "aws_api_gateway_method" "update_first_sign_in_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.update_first_sign_in.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "update_first_sign_in" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.update_first_sign_in.id
  http_method             = aws_api_gateway_method.update_first_sign_in_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_attributes.invoke_arn
}

# CORS for update-first-sign-in
resource "aws_api_gateway_method" "update_first_sign_in_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.update_first_sign_in.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "update_first_sign_in_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.update_first_sign_in.id
  http_method = aws_api_gateway_method.update_first_sign_in_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "update_first_sign_in_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.update_first_sign_in.id
  http_method = aws_api_gateway_method.update_first_sign_in_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "update_first_sign_in_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.update_first_sign_in.id
  http_method = aws_api_gateway_method.update_first_sign_in_options.http_method
  status_code = aws_api_gateway_method_response.update_first_sign_in_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ─── /upload-quota Resource ───────────────────────────────────────────────

resource "aws_api_gateway_resource" "upload_quota" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "upload-quota"
}

resource "aws_api_gateway_method" "upload_quota_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload_quota.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "upload_quota" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.upload_quota.id
  http_method             = aws_api_gateway_method.upload_quota_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.check_or_increment_quota.invoke_arn
}

# CORS for upload-quota
resource "aws_api_gateway_method" "upload_quota_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload_quota.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_quota_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload_quota.id
  http_method = aws_api_gateway_method.upload_quota_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "upload_quota_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload_quota.id
  http_method = aws_api_gateway_method.upload_quota_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "upload_quota_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload_quota.id
  http_method = aws_api_gateway_method.upload_quota_options.http_method
  status_code = aws_api_gateway_method_response.upload_quota_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ─── Lambda Permissions for API Gateway ───────────────────────────────────

resource "aws_lambda_permission" "apigw_update_attributes" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_attributes.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_check_quota" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_or_increment_quota.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ─── Deployment & Stage ───────────────────────────────────────────────────

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.update_first_sign_in.id,
      aws_api_gateway_method.update_first_sign_in_post.id,
      aws_api_gateway_integration.update_first_sign_in.id,
      aws_api_gateway_resource.upload_quota.id,
      aws_api_gateway_method.upload_quota_post.id,
      aws_api_gateway_integration.upload_quota.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.update_first_sign_in,
    aws_api_gateway_integration.upload_quota,
    aws_api_gateway_integration.update_first_sign_in_options,
    aws_api_gateway_integration.upload_quota_options,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"

  tags = {
    Name = "pdf-accessibility-${var.environment}-api-prod"
  }
}
