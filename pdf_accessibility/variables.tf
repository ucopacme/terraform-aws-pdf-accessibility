variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "environment" {
  type    = string
  default = "production"
}

variable "vpc_cidr" {
  type    = string
  default = "172.20.0.0/16"
}

variable "max_azs" {
  type    = number
  default = 2
}

variable "adobe_client_id" {
  type      = string
  sensitive = true
}

variable "adobe_client_secret" {
  type      = string
  sensitive = true
}

# Source code paths
variable "pdf_splitter_source_dir" {
  type = string
}

variable "pdf_merger_jar_path" {
  type = string
}

variable "title_generator_source_dir" {
  type = string
}

variable "pre_remediation_checker_source_dir" {
  type = string
}

variable "post_remediation_checker_source_dir" {
  type = string
}

variable "adobe_autotag_container_dir" {
  type = string
}

variable "alt_text_generator_container_dir" {
  type = string
}
