output "amplify_app_url" {
  value = "https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com"
}

output "amplify_app_id" {
  value = aws_amplify_app.pdf_ui.id
}

output "user_pool_id" {
  value = aws_cognito_user_pool.pdf_ui.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.pdf_ui.id
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.pdf_ui.id
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}

output "update_first_sign_in_endpoint" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/update-first-sign-in"
}

output "upload_quota_endpoint" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/upload-quota"
}
