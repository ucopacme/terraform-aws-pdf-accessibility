# ─── PDF-to-PDF Outputs ─────────────────────────────────────────────────────

output "pdf2pdf_bucket_name" {
  description = "S3 bucket name for PDF-to-PDF processing"
  value       = local.deploy_pdf2pdf ? module.pdf_accessibility[0].bucket_name : null
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = local.deploy_pdf2pdf ? module.pdf_accessibility[0].state_machine_arn : null
}

# ─── PDF-to-HTML Outputs ───────────────────────────────────────────────────

output "pdf2html_bucket_name" {
  description = "S3 bucket name for PDF-to-HTML processing"
  value       = local.deploy_pdf2html ? module.pdf2html[0].bucket_name : null
}

output "pdf2html_lambda_function_name" {
  description = "PDF-to-HTML Lambda function name"
  value       = local.deploy_pdf2html ? module.pdf2html[0].lambda_function_name : null
}

# ─── UI Outputs ─────────────────────────────────────────────────────────────

output "amplify_app_url" {
  description = "Amplify application URL"
  value       = local.deploy_ui ? module.pdf_ui[0].amplify_app_url : null
}

output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = local.deploy_ui ? module.pdf_ui[0].user_pool_id : null
}

output "user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = local.deploy_ui ? module.pdf_ui[0].user_pool_client_id : null
}

output "identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = local.deploy_ui ? module.pdf_ui[0].identity_pool_id : null
}

output "api_gateway_url" {
  description = "API Gateway base URL"
  value       = local.deploy_ui ? module.pdf_ui[0].api_gateway_url : null
}
