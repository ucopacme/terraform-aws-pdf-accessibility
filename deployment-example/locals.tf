# ═══════════════════════════════════════════════════════════════════════════
# Local Values — all deployment configuration in one place
# ═══════════════════════════════════════════════════════════════════════════

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # ─── Project ──────────────────────────────────────────────────────────
  # CHANGE THESE for your account
  aws_region   = "us-west-2"
  project_name = "pdf-accessibility"
  environment  = "CHANGEME" # e.g., "dev", "staging", "prod"

  # ─── Feature Flags ────────────────────────────────────────────────────
  # Toggle which components to deploy. Set to false to skip a module.
  deploy_pdf2pdf  = true # PDF-to-PDF remediation pipeline (Step Functions + ECS)
  deploy_pdf2html = true # PDF-to-HTML conversion (Bedrock Data Automation)
  deploy_ui       = true # Frontend UI (Amplify + Cognito)

  # ─── PDF-to-HTML ──────────────────────────────────────────────────────
  bda_project_arn = "" # Leave empty to auto-create a Bedrock Data Automation project

  # ─── Adobe API keys ──────────────────────────────────────────────────────
  # These are PLACEHOLDERS. After deployment, update the real keys in:
  #   AWS Console → Secrets Manager → /myapp/client_credentials
  adobe_client_id     = "placeholder-update-in-secrets-manager"
  adobe_client_secret = "placeholder-update-in-secrets-manager"

  # ─── S3 Lifecycle ──────────────────────────────────────────────────────
  enable_s3_lifecycle           = true
  s3_object_expiration_days     = 3  # Days before processed PDFs are deleted
  s3_cloudtrail_expiration_days = 10 # Days before CloudTrail logs are deleted

  # ─── ECS Task Resources ──────────────────────────────────────────────
  # Fargate CPU/memory for the ECS containers
  autotag_cpu     = 256  # Adobe Autotag container
  autotag_memory  = 1024
  alt_text_cpu    = 512  # Alt Text Generator container
  alt_text_memory = 2048

  # ─── Lambda Source Paths ──────────────────────────────────────────────
  pdf_merger_jar_path   = "lambda/pdf-merger/PDFMergerLambda-1.0-SNAPSHOT.jar"
  ui_lambda_source_path = "lambda"

  # ─── Networking ───────────────────────────────────────────────────────
  # CHANGE: Pick a CIDR that doesn't overlap with existing VPCs in your org
  vpc_cidr = "172.20.0.0/16"
  max_azs  = 2

  # ─── Custom Domain ─────────────────────────────────────────────────
  # Set to your domain (requires Route53 setup) or "" to use default Amplify URL
  custom_domain = "" # e.g., "example.com"

  # ─── GitHub Repos ─────────────────────────────────────────────────────
  # These are the UCOP private repos — do not change unless forked
  backend_github_repo_url = "https://github.com/ucopacme/PDF_Accessibility.git"
  ui_github_repo_url      = "https://github.com/ucopacme/PDF_accessability_UI.git"
  github_branch           = "main"

  # ─── SAML Identity Provider ──────────────────────────────────────────
  # Set enable_cognito_provider = false for initial deployment.
  # Enable after SAML IdP metadata is configured.
  enable_cognito_provider = false
  saml_provider_name      = "SSO"  # Name for your SAML provider
  saml_metadata_url       = ""                                 # Use URL OR file, not both
  saml_metadata_file      = "${path.module}/samlproxy-idp.xml" # Place your IdP metadata XML here
  saml_identifiers        = []
  saml_sign_out_enabled   = false
  saml_idp_initiated      = false
  saml_sign_requests      = true
  saml_encrypt_assertions = true
  saml_attribute_mapping = {
    email       = "urn:oid:0.9.2342.19200300.100.1.3"
    given_name  = "urn:oid:2.5.4.42"
    family_name = "urn:oid:2.5.4.4"
  }

  # ─── Standard Tags ──────────────────────────────────────────────────
  # Adjust tag keys/values to match your organization's tagging standard
  ucop_application = "pdf-accessibility"
  ucop_created_by  = "terraform"
  ucop_environment = "CHANGEME" # Must match `environment` above
  ucop_group       = "CHANGEME" # Your team/group code
  ucop_source      = "CHANGEME" # Link to your deployment repo/folder
}
