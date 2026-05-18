terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      Name               = local.project_name
      "ucop:application" = local.ucop_application
      "ucop:createdBy"   = local.ucop_created_by
      "ucop:environment" = local.ucop_environment
      "ucop:group"       = local.ucop_group
      "ucop:source"      = local.ucop_source
    }
  }
}
