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

variable "custom_domain" {
  description = "Custom domain for the frontend (e.g. pdf.prod.dxe.aws.ucop.edu). If empty, uses the default Amplify URL."
  type        = string
  default     = ""
}

# ─── SAML Identity Provider ─────────────────────────────────────────────────

variable "saml_provider_name" {
  description = "Friendly name for the SAML 2.0 identity provider"
  type        = string
  default     = ""
}

variable "saml_metadata_url" {
  description = "URL to the SAML metadata document endpoint. Mutually exclusive with saml_metadata_file."
  type        = string
  default     = ""
}

variable "saml_metadata_file" {
  description = "Path to the SAML metadata XML file. Mutually exclusive with saml_metadata_url."
  type        = string
  default     = ""
}

variable "saml_identifiers" {
  description = "List of identifiers for the SAML provider (used in multitenant apps)"
  type        = list(string)
  default     = []
}

variable "saml_sign_out_enabled" {
  description = "Enable simultaneous sign-out from the SAML provider and Cognito"
  type        = bool
  default     = false
}

variable "saml_idp_initiated" {
  description = "Accept IdP-initiated SAML assertions (false = SP-initiated only, recommended)"
  type        = bool
  default     = false
}

variable "saml_sign_requests" {
  description = "Sign SAML requests to this provider"
  type        = bool
  default     = false
}

variable "saml_encrypt_assertions" {
  description = "Require encrypted SAML assertions from this provider"
  type        = bool
  default     = false
}

variable "saml_attribute_mapping" {
  description = "Map of Cognito user pool attributes to SAML attributes"
  type        = map(string)
  default     = {}
}

variable "enable_cognito_provider" {
  description = "Include Cognito user pool directory as an identity provider"
  type        = bool
  default     = true
}
