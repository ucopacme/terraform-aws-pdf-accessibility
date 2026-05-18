# PDF Accessibility — Deployment Example

Complete working example for deploying the PDF Accessibility solution to a new AWS account.

## What Gets Deployed

| Component | Resources |
|-----------|-----------|
| **PDF-to-PDF** | VPC, ECS Fargate cluster, 6 ECR repos, Step Functions, 5 Lambdas, S3, Secrets Manager, CodeBuild, CloudWatch dashboard |
| **PDF-to-HTML** | S3 bucket, ECR repo, Lambda, CodeBuild, Bedrock Data Automation |
| **Frontend UI** | Amplify app, Cognito (User Pool + Identity Pool), API Gateway, 5 Lambdas, CloudTrail + EventBridge, CodeBuild |
| **GitHub Auth** | CodeStar Connection, CodeBuild Source Credential, IAM policies |

## Prerequisites

- [ ] AWS account provisioned
- [ ] Terraform remote backend configured (see `backend.tf.example`)
- [ ] Terraform >= 1.5 installed
- [ ] AWS CLI configured with credentials for the target account
- [ ] GitHub SSH access (`git@github.com:ucopacme/...` must work)
- [ ] Adobe PDF Services API credentials ([Adobe Developer Console](https://developer.adobe.com/console/))
- [ ] Lambda zip files built (see [docs/lambda-zip-build-guide.md](docs/lambda-zip-build-guide.md))

## Directory Structure

```
deployment-example/
├── main.tf              # Module calls and S3 lifecycle rules
├── locals.tf            # All configuration values (edit this)
├── github.tf            # CodeStar Connection and CodeBuild credentials
├── outputs.tf           # Key outputs (URLs, bucket names, IDs)
├── versions.tf          # Provider versions and default tags
├── backend.tf.example   # Terraform state backend examples (copy to backend.tf)
├── samlproxy-idp.xml    # SAML IdP metadata (copy from your IdP)
├── README.md            # This file
├── docs/
│   └── lambda-zip-build-guide.md
└── lambda/
    ├── zip/             # Built Lambda zip packages (see build guide)
    │   ├── pdf-splitter.zip
    │   ├── title-generator.zip
    │   ├── pre-remediation-checker.zip
    │   ├── post-remediation-checker.zip
    │   └── pdf2html.zip
    ├── pdf-merger/
    │   └── PDFMergerLambda-1.0-SNAPSHOT.jar
    ├── preSignUp/index.py
    ├── postConfirmation/index.py
    ├── updateAttributes/index.py
    ├── UpdateAttributesGroups/index.py
    └── checkOrIncrementQuota/index.py
```

---

## Step-by-Step Deployment

### 1. Copy This Directory

Copy `deployment-example/` to your deployment location:

```bash
cp -r deployment-example/ /path/to/your/terraform/<account-name>/pdf-accessibility/
cd /path/to/your/terraform/<account-name>/pdf-accessibility/
```

### 2. Lambda Files (pre-included)

All Lambda zip packages, the PDF Merger JAR, and Python source files are **already included** in this directory. No build step is needed for initial deployment.

> **Rebuilding zips is only required when updating Lambda code.** See [docs/lambda-zip-build-guide.md](docs/lambda-zip-build-guide.md) for instructions.

### 3. Configure `backend.tf`

Copy `backend.tf.example` to `backend.tf` and fill in your remote backend details:

```bash
cp backend.tf.example backend.tf
```

Edit `backend.tf` with your organization's state backend (Scalr, S3, Terraform Cloud, etc.).

### 4. Configure `locals.tf`

Search for `CHANGEME` and update:

| Value | What to set |
|-------|-------------|
| `environment` | `"dev"`, `"staging"`, or `"prod"` |
| `vpc_cidr` | Unique CIDR (check with networking team) |
| `custom_domain` | Your domain or `""` for default Amplify URL |
| `ucop_environment` | Same as `environment` |
| `ucop_source` | Path to your deployment folder |

### 5. Place SAML Metadata (optional)

If using SAML SSO, copy your IdP metadata XML to `samlproxy-idp.xml`. Otherwise leave `enable_cognito_provider = false`.

### 6. Initialize Terraform

```bash
terraform init
```

### 7. Plan

```bash
terraform plan
```

Expect ~80-120 resources. Review for correctness.

### 8. Apply

```bash
terraform apply
```

Takes ~10-15 minutes.

### 9. Complete GitHub CodeStar Connection

After apply, the connection is in **Pending** status:

1. AWS Console → **CodeBuild** → **Settings** → **Connections**
2. Find `pdf-accessibility-github` → click **Update pending connection**
3. Authorize the AWS Connector for GitHub
4. **Install a new app** → select `ucopacme` org
5. Select repos: `PDF_Accessibility` and `PDF_accessability_UI`
6. Confirm — status changes to **Available**

### 10. Trigger CodeBuild

```bash
# Build backend Docker images (ECS + container Lambdas)
aws codebuild start-build --project-name pdf-accessibility-<env>-image-builder --region us-west-2

# Build and deploy frontend to Amplify
aws codebuild start-build --project-name pdf-accessibility-<env>-frontend-builder --region us-west-2
```

### 11. Update Adobe Credentials

1. AWS Console → **Secrets Manager** → `/myapp/client_credentials`
2. Click **Retrieve secret value** → **Edit**
3. Set `client_id` and `client_secret` to your real Adobe API keys

### 12. Verify

```bash
terraform output
```

- Open `amplify_app_url` in a browser
- Upload a test PDF through the UI
- Check Step Functions console for execution status

---

## Post-Deployment Checklist

- [ ] CodeStar Connection = **Available**
- [ ] Backend CodeBuild completed (check CloudWatch logs if failed)
- [ ] Frontend CodeBuild completed
- [ ] Amplify URL loads the React app
- [ ] Adobe credentials set in Secrets Manager
- [ ] Test PDF upload works end-to-end
- [ ] S3 lifecycle rules active
- [ ] (Optional) Custom domain DNS configured
- [ ] (Optional) SAML SSO tested

## Updating After Deployment

| What changed | Action |
|--------------|--------|
| UI Lambda code (`lambda/*.py`) | Edit file, run `terraform apply` |
| PDF Merger JAR | Rebuild JAR, copy to `lambda/pdf-merger/`, run `terraform apply` |
| Backend Docker images | Push to GitHub, trigger CodeBuild |
| Frontend React code | Push to GitHub, trigger frontend CodeBuild |
| Terraform module updates | `terraform init -upgrade && terraform apply` |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| CodeBuild "source not found" | CodeStar Connection not activated — complete Step 9 |
| Lambda "image does not exist" | CodeBuild hasn't run yet — complete Step 10 |
| Amplify blank page | Frontend CodeBuild still running — wait or check logs |
| CORS errors on upload | Set `custom_domain` in locals.tf, re-apply |
| "No matching state found" on login | Cognito callback URLs need the domain you're accessing from |
| Adobe Autotag fails | Check Secrets Manager credentials (Step 11) |

## Source Repositories

| Repository | Description |
|------------|-------------|
| [terraform-aws-pdf-accessibility](https://github.com/ucopacme/terraform-aws-pdf-accessibility) | Terraform modules (this repo) |
| [PDF_Accessibility](https://github.com/ucopacme/PDF_Accessibility) | Backend Lambda + ECS source code |
| [PDF_accessability_UI](https://github.com/ucopacme/PDF_accessability_UI) | React frontend source code |

All three repos are **private** (UCOP org access required).
