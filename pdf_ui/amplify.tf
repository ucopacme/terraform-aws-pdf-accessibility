# ═══════════════════════════════════════════════════════════════════════════
# AWS Amplify App (Manual Deployment)
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_amplify_app" "pdf_ui" {
  name        = "pdf-accessibility-${var.environment}-ui"
  description = "PDF Accessibility UI - Manual Deployment"

  # SPA redirect rules
  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json)$)([^.]+$)/>"
    target = "/index.html"
    status = "200"
  }

  custom_rule {
    source = "/home"
    target = "/index.html"
    status = "200"
  }

  custom_rule {
    source = "/callback"
    target = "/index.html"
    status = "200"
  }

  custom_rule {
    source = "/app"
    target = "/index.html"
    status = "200"
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-ui"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.pdf_ui.id
  branch_name = "main"
  stage       = "PRODUCTION"

  environment_variables = merge(
    {
      REACT_APP_BUCKET_REGION        = var.aws_region
      REACT_APP_AWS_REGION           = var.aws_region
      REACT_APP_USER_POOL_ID         = aws_cognito_user_pool.pdf_ui.id
      REACT_APP_AUTHORITY            = "cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.pdf_ui.id}"
      REACT_APP_USER_POOL_CLIENT_ID  = aws_cognito_user_pool_client.pdf_ui.id
      REACT_APP_IDENTITY_POOL_ID     = aws_cognito_identity_pool.pdf_ui.id
      REACT_APP_HOSTED_UI_URL        = "https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com"
      REACT_APP_DOMAIN_PREFIX        = local.domain_prefix
      REACT_APP_UPDATE_FIRST_SIGN_IN = "${aws_api_gateway_stage.prod.invoke_url}/update-first-sign-in"
      REACT_APP_UPLOAD_QUOTA_API     = "${aws_api_gateway_stage.prod.invoke_url}/upload-quota"
    },
    var.deploy_pdf2pdf ? {
      REACT_APP_PDF_BUCKET_NAME = var.pdf_to_pdf_bucket_name
      REACT_APP_BUCKET_NAME     = var.pdf_to_pdf_bucket_name
    } : {},
    var.deploy_pdf2html ? {
      REACT_APP_HTML_BUCKET_NAME = var.pdf_to_html_bucket_name
    } : {},
    !var.deploy_pdf2pdf && var.deploy_pdf2html ? {
      REACT_APP_BUCKET_NAME = var.pdf_to_html_bucket_name
    } : {}
  )
}

# ─── S3 CORS Configuration via AWS CLI ────────────────────────────────────

resource "null_resource" "pdf_bucket_cors" {
  count = var.deploy_pdf2pdf ? 1 : 0

  triggers = {
    bucket_name = var.pdf_to_pdf_bucket_name
    app_url     = "https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3api put-bucket-cors --bucket ${var.pdf_to_pdf_bucket_name} --cors-configuration '{
        "CORSRules": [{
          "AllowedHeaders": ["*"],
          "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
          "AllowedOrigins": ["https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com", "http://localhost:3000"],
          "ExposeHeaders": ["ETag"],
          "MaxAgeSeconds": 3600
        }]
      }'
    EOT
  }
}

resource "null_resource" "html_bucket_cors" {
  count = var.deploy_pdf2html ? 1 : 0

  triggers = {
    bucket_name = var.pdf_to_html_bucket_name
    app_url     = "https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3api put-bucket-cors --bucket ${var.pdf_to_html_bucket_name} --cors-configuration '{
        "CORSRules": [{
          "AllowedHeaders": ["*"],
          "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
          "AllowedOrigins": ["https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com", "http://localhost:3000"],
          "ExposeHeaders": ["ETag"],
          "MaxAgeSeconds": 3600
        }]
      }'
    EOT
  }
}
