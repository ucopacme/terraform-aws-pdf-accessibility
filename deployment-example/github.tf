resource "aws_codestarconnections_connection" "github" {
  name          = "pdf-accessibility-github"
  provider_type = "GitHub"
}

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = aws_codestarconnections_connection.github.arn
}

# Grant CodeBuild roles permission to use the connection
resource "aws_iam_role_policy" "codebuild_codeconnections" {
  for_each = toset([
    "pdf-accessibility-${local.environment}-codebuild-role",
    "pdf-accessibility-${local.environment}-frontend-codebuild-role",
  ])

  name = "codeconnections-access"
  role = each.value

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codeconnections:GetConnectionToken",
        "codeconnections:GetConnection"
      ]
      Resource = [aws_codestarconnections_connection.github.arn]
    }]
  })
}
