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

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

# ─── Lambda Source Paths ────────────────────────────────────────────────────

variable "ui_lambda_source_path" {
  description = "Local path to the UI Lambda source directories (containing postConfirmation/, updateAttributes/, etc.)"
  type        = string
}
