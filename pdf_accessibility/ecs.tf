# ═══════════════════════════════════════════════════════════════════════════
# ECS Cluster
# ═══════════════════════════════════════════════════════════════════════════

resource "aws_ecs_cluster" "pdf_remediation" {
  name = "pdf-accessibility-${var.environment}-ecs-cluster"

  tags = {
    Name = "pdf-accessibility-${var.environment}-ecs-cluster"
  }
}

# ─── ECR Repositories for Container Images ────────────────────────────────

resource "aws_ecr_repository" "adobe_autotag" {
  name                 = "pdf-accessibility/adobe-autotag"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "pdf-accessibility-adobe-autotag-ecr"
  }
}

resource "aws_ecr_repository" "alt_text_generator" {
  name                 = "pdf-accessibility/alt-text-generator"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "pdf-accessibility-alt-text-generator-ecr"
  }
}

# ─── Build and Push Docker Images (via CodeBuild — see codebuild.tf) ──────

# ─── ECS Task Execution Role ──────────────────────────────────────────────

resource "aws_iam_role" "ecs_task_execution" {
  name = "pdf-accessibility-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_s3" {
  name = "s3-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.pdf_processing.arn,
        "${aws_s3_bucket.pdf_processing.arn}/*"
      ]
    }]
  })
}

# ─── ECS Task Role (runtime permissions) ──────────────────────────────────

resource "aws_iam_role" "ecs_task" {
  name = "pdf-accessibility-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "pdf-accessibility-${var.environment}-ecs-task-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_basic" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "task-permissions"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockAccess"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["*"]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          aws_s3_bucket.pdf_processing.arn,
          "${aws_s3_bucket.pdf_processing.arn}/*"
        ]
      },
      {
        Sid      = "ComprehendAccess"
        Effect   = "Allow"
        Action   = ["comprehend:DetectDominantLanguage"]
        Resource = ["*"]
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = ["arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:/myapp/*"]
      }
    ]
  })
}

# ─── CloudWatch Log Groups for ECS ────────────────────────────────────────

resource "aws_cloudwatch_log_group" "adobe_autotag" {
  name              = "/ecs/pdf-remediation/adobe-autotag"
  retention_in_days = 30

  tags = {
    Name = "pdf-accessibility-adobe-autotag-logs"
  }
}

resource "aws_cloudwatch_log_group" "alt_text_generator" {
  name              = "/ecs/pdf-remediation/alt-text-generator"
  retention_in_days = 30

  tags = {
    Name = "pdf-accessibility-alt-text-generator-logs"
  }
}

# ─── ECS Task Definitions ─────────────────────────────────────────────────

resource "aws_ecs_task_definition" "adobe_autotag" {
  family                   = "pdf-accessibility-${var.environment}-adobe-autotag"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.autotag_cpu
  memory                   = var.autotag_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "adobe-autotag-container"
    image     = "${aws_ecr_repository.adobe_autotag.repository_url}:latest"
    essential = true
    memory    = var.autotag_memory

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.adobe_autotag.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "AdobeAutotagLogs"
      }
    }
  }])

  tags = {
    Name = "pdf-accessibility-${var.environment}-adobe-autotag-task"
  }

  depends_on = [null_resource.trigger_image_build]
}

resource "aws_ecs_task_definition" "alt_text_generator" {
  family                   = "pdf-accessibility-${var.environment}-alt-text-generator"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.alt_text_cpu
  memory                   = var.alt_text_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "alt-text-llm-container"
    image     = "${aws_ecr_repository.alt_text_generator.repository_url}:latest"
    essential = true
    memory    = var.alt_text_memory

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.alt_text_generator.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "AltTextGeneratorLogs"
      }
    }
  }])

  tags = {
    Name = "pdf-accessibility-${var.environment}-alt-text-generator-task"
  }

  depends_on = [null_resource.trigger_image_build]
}

# ─── Security Group for ECS Tasks ─────────────────────────────────────────

resource "aws_security_group" "ecs_tasks" {
  name        = "pdf-accessibility-${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS Fargate tasks - allows all outbound for S3/ECR/Bedrock access"
  vpc_id      = aws_vpc.pdf_processing.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pdf-accessibility-${var.environment}-ecs-tasks-sg"
  }
}
