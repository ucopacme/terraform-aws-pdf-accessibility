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


# ─── ECS Task Resources ────────────────────────────────────────────────────

variable "autotag_cpu" {
  description = "CPU units for Adobe Autotag ECS task"
  type        = number
  default     = 256
}

variable "autotag_memory" {
  description = "Memory (MB) for Adobe Autotag ECS task"
  type        = number
  default     = 1024
}

variable "alt_text_cpu" {
  description = "CPU units for Alt Text Generator ECS task"
  type        = number
  default     = 512
}

variable "alt_text_memory" {
  description = "Memory (MB) for Alt Text Generator ECS task"
  type        = number
  default     = 2048
}

# ─── Lambda Source Paths ────────────────────────────────────────────────────

variable "pdf_merger_jar_path" {
  description = "Local path to the pre-built PDF Merger Lambda JAR file (build with: mvn clean package)"
  type        = string
}