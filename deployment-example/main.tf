data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── PDF-to-PDF Backend Module ──────────────────────────────────────────────

module "pdf_accessibility" {
  source = "git::git@github.com:ucopacme/terraform-aws-pdf-accessibility.git//pdf_accessibility"
  count  = local.deploy_pdf2pdf ? 1 : 0

  project_name        = local.project_name
  aws_region          = local.aws_region
  account_id          = local.account_id
  environment         = local.environment
  vpc_cidr            = local.vpc_cidr
  max_azs             = local.max_azs
  adobe_client_id     = local.adobe_client_id
  adobe_client_secret = local.adobe_client_secret

  autotag_cpu     = local.autotag_cpu
  autotag_memory  = local.autotag_memory
  alt_text_cpu    = local.alt_text_cpu
  alt_text_memory = local.alt_text_memory

  pdf_merger_jar_path = local.pdf_merger_jar_path

  github_repo_url = local.backend_github_repo_url
  github_branch   = local.github_branch

  use_zip_lambdas = true
  lambda_zip_paths = {
    pdf_splitter             = "${path.module}/lambda/zip/pdf-splitter.zip"
    title_generator          = "${path.module}/lambda/zip/title-generator.zip"
    pre_remediation_checker  = "${path.module}/lambda/zip/pre-remediation-checker.zip"
    post_remediation_checker = "${path.module}/lambda/zip/post-remediation-checker.zip"
  }
}

# ─── PDF-to-HTML Module ────────────────────────────────────────────────────

module "pdf2html" {
  source = "git::git@github.com:ucopacme/terraform-aws-pdf-accessibility.git//pdf2html"
  count  = local.deploy_pdf2html ? 1 : 0

  project_name    = local.project_name
  aws_region      = local.aws_region
  account_id      = local.account_id
  environment     = local.environment
  bda_project_arn = local.bda_project_arn
  bucket_name     = join("-", ["pdf-accessibility-pdf-to-html", local.account_id, local.aws_region])

  github_repo_url = local.backend_github_repo_url
  github_branch   = local.github_branch

  use_zip_lambda  = true
  lambda_zip_path = "${path.module}/lambda/zip/pdf2html.zip"
}

# ─── Frontend UI Module ────────────────────────────────────────────────────

module "pdf_ui" {
  source = "git::git@github.com:ucopacme/terraform-aws-pdf-accessibility.git//pdf_ui"
  count  = local.deploy_ui ? 1 : 0

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  environment  = local.environment

  deploy_pdf2pdf  = local.deploy_pdf2pdf
  deploy_pdf2html = local.deploy_pdf2html

  pdf_to_pdf_bucket_name  = local.deploy_pdf2pdf ? module.pdf_accessibility[0].bucket_name : ""
  pdf_to_html_bucket_name = local.deploy_pdf2html ? module.pdf2html[0].bucket_name : ""
  pdf_to_pdf_bucket_arn   = local.deploy_pdf2pdf ? module.pdf_accessibility[0].bucket_arn : ""
  pdf_to_html_bucket_arn  = local.deploy_pdf2html ? module.pdf2html[0].bucket_arn : ""

  ui_lambda_source_path = local.ui_lambda_source_path

  custom_domain = local.custom_domain

  enable_cognito_provider = local.enable_cognito_provider
  saml_provider_name      = local.saml_provider_name
  saml_metadata_url       = local.saml_metadata_url
  saml_metadata_file      = local.saml_metadata_file
  saml_identifiers        = local.saml_identifiers
  saml_sign_out_enabled   = local.saml_sign_out_enabled
  saml_idp_initiated      = local.saml_idp_initiated
  saml_sign_requests      = local.saml_sign_requests
  saml_encrypt_assertions = local.saml_encrypt_assertions
  saml_attribute_mapping  = local.saml_attribute_mapping

  ui_github_repo_url = local.ui_github_repo_url
  ui_github_branch   = local.github_branch
}

# ─── S3 Lifecycle - Auto-delete objects after X days ────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "pdf2pdf" {
  count  = local.deploy_pdf2pdf && local.enable_s3_lifecycle ? 1 : 0
  bucket = module.pdf_accessibility[0].bucket_name

  rule {
    id     = "expire-objects"
    status = "Enabled"

    expiration {
      days = local.s3_object_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = local.s3_object_expiration_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pdf2html" {
  count  = local.deploy_pdf2html && local.enable_s3_lifecycle ? 1 : 0
  bucket = module.pdf2html[0].bucket_name

  rule {
    id     = "expire-objects"
    status = "Enabled"

    expiration {
      days = local.s3_object_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = local.s3_object_expiration_days
    }
  }
}
