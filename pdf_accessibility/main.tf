data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.max_azs)
}

# ═══════════════════════════════════════════════════════════════════════════
# S3 Bucket
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_s3_bucket" "pdf_processing" {
  bucket        = join("-", ["pdf-accessibility-pdf-to-pdf", var.account_id, var.aws_region])
  force_destroy = false

  tags = {
    Name = join("-", ["pdf-accessibility-pdf-to-pdf", var.account_id, var.aws_region])
  }
}

resource "aws_s3_bucket_versioning" "pdf_processing" {
  bucket = aws_s3_bucket.pdf_processing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pdf_processing" {
  bucket = aws_s3_bucket.pdf_processing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "enforce_ssl" {
  bucket = aws_s3_bucket.pdf_processing.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSL"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.pdf_processing.arn,
          "${aws_s3_bucket.pdf_processing.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ═══════════════════════════════════════════════════════════════════════════
# Secrets Manager - Adobe API Credentials
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_secretsmanager_secret" "adobe_credentials" {
  name                    = "/myapp/client_credentials"
  recovery_window_in_days = 0

  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "adobe_credentials" {
  secret_id = aws_secretsmanager_secret.adobe_credentials.id
  secret_string = jsonencode({
    client_credentials = {
      PDF_SERVICES_CLIENT_ID     = var.adobe_client_id
      PDF_SERVICES_CLIENT_SECRET = var.adobe_client_secret
    }
  })
}
