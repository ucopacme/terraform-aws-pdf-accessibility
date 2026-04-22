variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "pdf_to_pdf_bucket_name" {
  description = "S3 bucket name for PDF-to-PDF processing"
  type        = string
  default     = ""
}

variable "pdf_to_html_bucket_name" {
  description = "S3 bucket name for PDF-to-HTML processing"
  type        = string
  default     = ""
}

variable "pdf_to_pdf_bucket_arn" {
  description = "S3 bucket ARN for PDF-to-PDF processing"
  type        = string
  default     = ""
}

variable "pdf_to_html_bucket_arn" {
  description = "S3 bucket ARN for PDF-to-HTML processing"
  type        = string
  default     = ""
}

variable "deploy_pdf2pdf" {
  description = "Whether the PDF-to-PDF solution is deployed"
  type        = bool
  default     = false
}

variable "deploy_pdf2html" {
  description = "Whether the PDF-to-HTML solution is deployed"
  type        = bool
  default     = false
}

variable "lambda_source_base_dir" {
  description = "Base directory for Lambda function source code"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}
