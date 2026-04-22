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
