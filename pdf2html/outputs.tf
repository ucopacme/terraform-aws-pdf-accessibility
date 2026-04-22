output "bucket_name" {
  value = aws_s3_bucket.pdf2html.id
}

output "bucket_arn" {
  value = aws_s3_bucket.pdf2html.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.pdf2html.function_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.pdf2html.repository_url
}

output "bda_project_arn" {
  value = local.bda_project_arn
}
