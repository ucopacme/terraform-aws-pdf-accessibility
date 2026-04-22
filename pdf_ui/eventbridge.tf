# ═══════════════════════════════════════════════════════════════════════════
# CloudTrail + EventBridge for Cognito Group Changes
# ═══════════════════════════════════════════════════════════════════════════

# ─── CloudTrail ────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "cloudtrail" {
  bucket_prefix = "pdf-accessibility-${var.environment}-trail-"
  force_destroy = true

  tags = {
    Name = "pdf-accessibility-${var.environment}-cloudtrail-bucket"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "cognito" {
  name                          = "pdf-accessibility-${var.environment}-cognito-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_logging                = true

  tags = {
    Name = "pdf-accessibility-${var.environment}-cognito-trail"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ─── EventBridge Rule for Cognito Group Changes ───────────────────────────

resource "aws_cloudwatch_event_rule" "cognito_group_change" {
  name        = "pdf-accessibility-${var.environment}-cognito-group-change"
  description = "Triggers when users are added/removed from Cognito groups"

  event_pattern = jsonencode({
    source      = ["aws.cognito-idp"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["AdminAddUserToGroup", "AdminRemoveUserFromGroup"]
      requestParameters = {
        userPoolId = [aws_cognito_user_pool.pdf_ui.id]
      }
    }
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-cognito-group-change"
  }
}

resource "aws_cloudwatch_event_target" "cognito_group_change" {
  rule      = aws_cloudwatch_event_rule.cognito_group_change.name
  target_id = "UpdateAttributesGroupsLambda"
  arn       = aws_lambda_function.update_attributes_groups.arn
}
