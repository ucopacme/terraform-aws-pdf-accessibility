# terraform-aws-pdf-accessibility

Terraform modules for deploying the UC PDF Accessibility Remediation solution on AWS. This repo contains three independent modules that can be deployed together or separately.

## Modules

| Module | Description |
|--------|-------------|
| `pdf_accessibility` | PDF-to-PDF remediation pipeline (Step Functions, ECS Fargate, Lambda) |
| `pdf2html` | PDF-to-HTML conversion via Bedrock Data Automation |
| `pdf_ui` | React frontend with Cognito auth, API Gateway, and Amplify hosting |

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate credentials
- GitHub SSH access (modules are sourced via `git@github.com:`)
- Adobe PDF Services API credentials (for `pdf_accessibility`)
- Maven (only if rebuilding the PDF Merger JAR)

## Usage

Reference the modules from your Terraform configuration:

```hcl
module "pdf_accessibility" {
  source = "git::git@github.com:ucopacme/terraform-aws-pdf-accessibility.git//pdf_accessibility"

  project_name        = "pdf-accessibility"
  aws_region          = "us-west-2"
  account_id          = data.aws_caller_identity.current.account_id
  environment         = "prod"
  adobe_client_id     = var.adobe_client_id
  adobe_client_secret = var.adobe_client_secret
  pdf_merger_jar_path = "lambda/pdf-merger/PDFMergerLambda-1.0-SNAPSHOT.jar"
  github_repo_url     = "https://github.com/ucopacme/PDF_Accessibility.git"
  github_branch       = "main"
}

module "pdf2html" {
  source = "git::git@github.com:ucopacme/terraform-aws-pdf-accessibility.git//pdf2html"

  project_name    = "pdf-accessibility"
  aws_region      = "us-west-2"
  account_id      = data.aws_caller_identity.current.account_id
  environment     = "prod"
  bucket_name     = "my-pdf2html-bucket"
  github_repo_url = "https://github.com/ucopacme/PDF_Accessibility.git"
  github_branch   = "main"
}

module "pdf_ui" {
  source = "git::git@github.com:ucopacme/terraform-aws-pdf-accessibility.git//pdf_ui"

  project_name          = "pdf-accessibility"
  aws_region            = "us-west-2"
  account_id            = data.aws_caller_identity.current.account_id
  environment           = "prod"
  deploy_pdf2pdf        = true
  deploy_pdf2html       = true
  pdf_to_pdf_bucket_name  = module.pdf_accessibility.bucket_name
  pdf_to_html_bucket_name = module.pdf2html.bucket_name
  pdf_to_pdf_bucket_arn   = module.pdf_accessibility.bucket_arn
  pdf_to_html_bucket_arn  = module.pdf2html.bucket_arn
  ui_lambda_source_path   = "lambda"
  ui_github_repo_url      = "https://github.com/ucopacme/PDF_accessability_UI.git"
  ui_github_branch        = "main"
}
```

## Module: pdf_accessibility

PDF-to-PDF remediation pipeline using Adobe PDF Services, Amazon Bedrock, and Step Functions.

### Architecture

```
S3 Upload → PDF Splitter Lambda → Step Functions:
  ├─ [Parallel per chunk] Adobe Autotag (ECS) → Alt Text Gen (ECS)
  ├─ PDF Merger Lambda → Title Generator Lambda → Post-Remediation Check
  └─ Pre-Remediation Check (runs in parallel with remediation)
```

### Resources Created

- VPC with public/private subnets and NAT gateway
- ECS Fargate cluster with 2 task definitions (Adobe Autotag, Alt Text Generator)
- 6 ECR repositories (2 ECS + 4 container Lambdas)
- 5 Lambda functions (splitter, merger, title gen, pre/post checker)
- Step Functions state machine
- S3 bucket for PDF processing
- Secrets Manager secret for Adobe API credentials
- CodeBuild project for Docker image builds
- CloudWatch dashboard

### Variables

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_name` | string | yes | Project name prefix |
| `aws_region` | string | yes | AWS region |
| `account_id` | string | yes | AWS account ID |
| `adobe_client_id` | string | yes | Adobe PDF Services Client ID |
| `adobe_client_secret` | string | yes | Adobe PDF Services Client Secret |
| `pdf_merger_jar_path` | string | yes | Local path to pre-built PDF Merger JAR |
| `environment` | string | no | Environment name (default: `production`) |
| `vpc_cidr` | string | no | VPC CIDR block (default: `172.20.0.0/16`) |
| `max_azs` | number | no | Max availability zones (default: `2`) |
| `autotag_cpu` | number | no | CPU for Autotag ECS task (default: `256`) |
| `autotag_memory` | number | no | Memory for Autotag ECS task (default: `1024`) |
| `alt_text_cpu` | number | no | CPU for Alt Text ECS task (default: `512`) |
| `alt_text_memory` | number | no | Memory for Alt Text ECS task (default: `2048`) |
| `github_repo_url` | string | no | Backend source repo URL |
| `github_branch` | string | no | Branch to build from (default: `main`) |

### Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | S3 bucket name for PDF processing |
| `bucket_arn` | S3 bucket ARN |
| `state_machine_arn` | Step Functions state machine ARN |
| `ecs_cluster_arn` | ECS cluster ARN |
| `vpc_id` | VPC ID |

### Lambda Packaging

| Lambda | Packaging | Notes |
|--------|-----------|-------|
| PDF Merger | Local JAR via `filename` | Pre-built with Maven, passed via `pdf_merger_jar_path` |
| PDF Splitter, Title Gen, Pre/Post Checker | Container image via ECR | Built by CodeBuild from GitHub |

---

## Module: pdf2html

PDF-to-HTML conversion using Amazon Bedrock Data Automation.

### Resources Created

- S3 bucket with uploads/output/remediated folder structure
- ECR repository for Lambda container image
- Lambda function (container-based)
- CodeBuild project for Docker image build
- Bedrock Data Automation project (auto-created if ARN not provided)

### Variables

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_name` | string | yes | Project name prefix |
| `aws_region` | string | yes | AWS region |
| `account_id` | string | yes | AWS account ID |
| `bucket_name` | string | yes | S3 bucket name |
| `environment` | string | no | Environment name (default: `production`) |
| `bda_project_arn` | string | no | Bedrock Data Automation project ARN (auto-created if empty) |
| `github_repo_url` | string | no | Backend source repo URL |
| `github_branch` | string | no | Branch to build from (default: `main`) |

### Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | S3 bucket name |
| `bucket_arn` | S3 bucket ARN |
| `lambda_function_name` | Lambda function name |
| `ecr_repository_url` | ECR repository URL |
| `bda_project_arn` | Bedrock Data Automation project ARN |

---

## Module: pdf_ui

React frontend with Cognito authentication, API Gateway, and Amplify hosting.

### Resources Created

- Amplify app with main branch
- Cognito User Pool with 3 groups (Default, Amazon, Admin)
- Cognito Identity Pool for S3 access
- API Gateway (REST) with Cognito authorizer
- 5 Lambda functions (post-confirmation, update-attributes, quota check, group updates, pre-signup)
- CloudTrail + EventBridge for Cognito group change tracking
- CodeBuild project for frontend builds
- S3 CORS configuration on processing buckets

### Variables

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_name` | string | yes | Project name prefix |
| `aws_region` | string | yes | AWS region |
| `account_id` | string | yes | AWS account ID |
| `ui_lambda_source_path` | string | yes | Local path to UI Lambda source directories |
| `environment` | string | no | Environment name (default: `production`) |
| `deploy_pdf2pdf` | bool | no | Whether PDF-to-PDF is deployed (default: `false`) |
| `deploy_pdf2html` | bool | no | Whether PDF-to-HTML is deployed (default: `false`) |
| `pdf_to_pdf_bucket_name` | string | no | PDF-to-PDF S3 bucket name |
| `pdf_to_pdf_bucket_arn` | string | no | PDF-to-PDF S3 bucket ARN |
| `pdf_to_html_bucket_name` | string | no | PDF-to-HTML S3 bucket name |
| `pdf_to_html_bucket_arn` | string | no | PDF-to-HTML S3 bucket ARN |
| `ui_github_repo_url` | string | no | UI source repo URL |
| `ui_github_branch` | string | no | Branch to build from (default: `main`) |

### Outputs

| Name | Description |
|------|-------------|
| `amplify_app_url` | Frontend URL |
| `amplify_app_id` | Amplify app ID |
| `user_pool_id` | Cognito User Pool ID |
| `user_pool_client_id` | Cognito User Pool Client ID |
| `identity_pool_id` | Cognito Identity Pool ID |
| `api_gateway_url` | API Gateway base URL |

### Lambda Packaging

All 5 UI Lambdas are packaged locally using Terraform's `archive_file` data source. Point `ui_lambda_source_path` to a directory containing:

```
<ui_lambda_source_path>/
├── postConfirmation/index.py
├── updateAttributes/index.py
├── checkOrIncrementQuota/index.py
├── UpdateAttributesGroups/index.py
└── preSignUp/index.py
```

---

## Updating Resources After Deployment

### UI Lambdas

Update the Python source files, then run `terraform apply`. Terraform detects changes via `source_code_hash`.

### PDF Merger JAR

Rebuild with Maven (`mvn clean package`), copy the JAR to the path specified in `pdf_merger_jar_path`, then run `terraform apply`.

### Docker-Based Lambdas and ECS Tasks

Push code changes to the GitHub repo, then trigger CodeBuild:

```bash
aws codebuild start-build --project-name <project-name> --region <region>
```

New Step Function executions will automatically use the latest container images.

### Frontend UI

Push changes to the UI GitHub repo, then trigger the frontend CodeBuild:

```bash
aws codebuild start-build --project-name <frontend-builder-project> --region <region>
```

### Terraform Module Updates

After pushing changes to this repo, consumers should run:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## License

See [LICENSE](LICENSE) for details.
