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
