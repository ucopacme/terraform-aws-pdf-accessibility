variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "bda_project_arn" {
  description = "ARN of the Bedrock Data Automation project"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for PDF-to-HTML processing"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "use_zip_lambda" {
  description = "Use zip deployment instead of container image"
  type        = bool
  default     = false
}

variable "lambda_zip_path" {
  description = "Path to the Lambda zip file (required when use_zip_lambda = true)"
  type        = string
  default     = ""
}
