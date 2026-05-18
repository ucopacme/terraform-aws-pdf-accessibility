# ═══════════════════════════════════════════════════════════════════════════
# Cognito User Pool, Groups, Domain, Client, Identity Pool
# ═══════════════════════════════════════════════════════════════════════════

locals {
  domain_prefix = "pdf-ui-auth-${var.account_id}-${var.aws_region}"
  default_group = "DefaultUsers"
  amazon_group  = "AmazonUsers"
  admin_group   = "AdminUsers"
  app_url       = "https://main.${aws_amplify_app.pdf_ui.id}.amplifyapp.com"
}

# ─── User Pool ─────────────────────────────────────────────────────────────

resource "aws_cognito_user_pool" "pdf_ui" {
  name = "pdf-accessibility-${var.environment}-user-pool"

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = false
    temporary_password_validity_days = 7
  }

  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_subject_by_link = "Verify your email for PDF Accessibility"
    email_message_by_link = "Please click the link below to verify your email address: {##Verify Email##}"
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name                = "family_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  # Custom attributes
  schema {
    name                = "first_sign_in"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 10
    }
  }

  schema {
    name                = "total_files_uploaded"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = 0
      max_value = 999999
    }
  }

  schema {
    name                = "max_files_allowed"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = 0
      max_value = 999999
    }
  }

  schema {
    name                = "max_pages_allowed"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = 0
      max_value = 999999
    }
  }

  schema {
    name                = "max_size_allowed_MB"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = 0
      max_value = 999999
    }
  }

  schema {
    name                = "organization"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  schema {
    name                = "country"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  schema {
    name                = "state"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  schema {
    name                = "city"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  schema {
    name                = "pdf2pdf"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = 0
      max_value = 999999
    }
  }

  schema {
    name                = "pdf2html"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = 0
      max_value = 999999
    }
  }

  lambda_config {
    post_confirmation = aws_lambda_function.post_confirmation.arn
    pre_sign_up       = aws_lambda_function.pre_sign_up.arn
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-user-pool"
  }
}

# ─── User Pool Domain ─────────────────────────────────────────────────────

resource "aws_cognito_user_pool_domain" "pdf_ui" {
  domain       = local.domain_prefix
  user_pool_id = aws_cognito_user_pool.pdf_ui.id
}

# ─── SAML Identity Provider ────────────────────────────────────────────────

resource "aws_cognito_identity_provider" "saml" {
  count         = var.saml_provider_name != "" ? 1 : 0
  user_pool_id  = aws_cognito_user_pool.pdf_ui.id
  provider_name = var.saml_provider_name
  provider_type = "SAML"

  provider_details = merge(
    var.saml_metadata_url != "" ? { MetadataURL = var.saml_metadata_url } : { MetadataFile = file(var.saml_metadata_file) },
    {
      IDPSignout              = tostring(var.saml_sign_out_enabled)
      IDPInit                 = tostring(var.saml_idp_initiated)
      RequestSigningAlgorithm = "rsa-sha256"
      EncryptedResponses      = tostring(var.saml_encrypt_assertions)
    }
  )

  idp_identifiers = var.saml_identifiers

  attribute_mapping = var.saml_attribute_mapping
}

# ─── User Pool Client ─────────────────────────────────────────────────────

resource "aws_cognito_user_pool_client" "pdf_ui" {
  name         = "pdf-accessibility-${var.environment}-user-pool-client"
  user_pool_id = aws_cognito_user_pool.pdf_ui.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  allowed_oauth_flows = [
    "code",
    "implicit"
  ]

  allowed_oauth_scopes = [
    "openid",
    "email",
    "phone",
    "profile"
  ]

  allowed_oauth_flows_user_pool_client = true

  callback_urls = compact([
    "${local.app_url}/callback",
    "http://localhost:3000/callback",
    var.custom_domain != "" ? "https://${var.custom_domain}/callback" : "",
  ])

  logout_urls = compact([
    "${local.app_url}/home",
    "http://localhost:3000/home",
    var.custom_domain != "" ? "https://${var.custom_domain}/home" : "",
  ])

  supported_identity_providers = compact(concat(
    ["COGNITO"],
    var.saml_provider_name != "" ? [var.saml_provider_name] : []
  ))

  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_identity_provider.saml]
}

# ─── User Pool Groups ─────────────────────────────────────────────────────

resource "aws_cognito_user_group" "default_users" {
  name         = local.default_group
  user_pool_id = aws_cognito_user_pool.pdf_ui.id
  description  = "Group for default or normal users"
  precedence   = 1
}

resource "aws_cognito_user_group" "amazon_users" {
  name         = local.amazon_group
  user_pool_id = aws_cognito_user_pool.pdf_ui.id
  description  = "Group for Amazon Employees"
  precedence   = 2
}

resource "aws_cognito_user_group" "admin_users" {
  name         = local.admin_group
  user_pool_id = aws_cognito_user_pool.pdf_ui.id
  description  = "Group for admin users with elevated permissions"
  precedence   = 0
}

# ─── Identity Pool ────────────────────────────────────────────────────────

resource "aws_cognito_identity_pool" "pdf_ui" {
  identity_pool_name               = "pdf-accessibility-${var.environment}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.pdf_ui.id
    provider_name           = aws_cognito_user_pool.pdf_ui.endpoint
    server_side_token_check = false
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-identity-pool"
  }
}

# ─── Identity Pool Authenticated Role ─────────────────────────────────────

resource "aws_iam_role" "cognito_authenticated" {
  name = "pdf-accessibility-${var.environment}-cognito-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "cognito-identity.amazonaws.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.pdf_ui.id
        }
        "ForAnyValue:StringLike" = {
          "cognito-identity.amazonaws.com:amr" = "authenticated"
        }
      }
    }]
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-cognito-authenticated-role"
  }
}

resource "aws_iam_role_policy" "cognito_authenticated_s3" {
  name = "s3-access"
  role = aws_iam_role.cognito_authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject"
      ]
      Resource = concat(
        var.deploy_pdf2pdf ? ["${var.pdf_to_pdf_bucket_arn}/*"] : [],
        var.deploy_pdf2html ? ["${var.pdf_to_html_bucket_arn}/*"] : []
      )
    }]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "pdf_ui" {
  identity_pool_id = aws_cognito_identity_pool.pdf_ui.id

  roles = {
    authenticated = aws_iam_role.cognito_authenticated.arn
  }
}
