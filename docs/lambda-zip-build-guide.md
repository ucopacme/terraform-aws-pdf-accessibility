# Lambda Zip File Build Guide

## Overview

This documents how to build the Lambda zip packages for the pdf-accessibility project. All Python Lambdas are packaged as zip files with dependencies targeting the AWS Lambda runtime (Linux x86_64, Python 3.12).

## Prerequisites

- Python 3.12+
- pip3
- zip utility

## Source Repository

```bash
git clone git@github.com:ucopacme/PDF_Accessibility.git
cd PDF_Accessibility
```

| Lambda | Path in Repo | Entry Point |
|--------|------------|-------------|
| pdf2html | `pdf2html/` | `lambda_function.lambda_handler` |
| pdf-splitter | `lambda/pdf-splitter-lambda/` | `main.lambda_handler` |
| title-generator | `lambda/title-generator-lambda/` | `title_generator.lambda_handler` |
| pre-remediation-checker | `lambda/pre-remediation-accessibility-checker/` | `main.lambda_handler` |
| post-remediation-checker | `lambda/post-remediation-accessibility-checker/` | `main.lambda_handler` |

## Deployment Location

All zips go to the terraform deployments repo:
```
ucop-terraform-deployments/terraform/dxe-prod/pdf-accessibility/lambda/zip/
```

---

## Building pdf2html.zip

```bash
git clone git@github.com:ucopacme/PDF_Accessibility.git
cd PDF_Accessibility/pdf2html

# Clean build directory
rm -rf /tmp/pdf2html-zip-build
mkdir -p /tmp/pdf2html-zip-build

# Install dependencies for Linux x86_64
pip3 install --no-cache-dir \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  -r requirements-zip.txt \
  -t /tmp/pdf2html-zip-build/

# Copy source code
cp lambda_function.py /tmp/pdf2html-zip-build/
cp -r content_accessibility_utility_on_aws /tmp/pdf2html-zip-build/

# Create zip
cd /tmp/pdf2html-zip-build
zip -r -q /tmp/pdf2html.zip .

# Deploy
cp /tmp/pdf2html.zip <DEPLOYMENTS_REPO>/terraform/dxe-prod/pdf-accessibility/lambda/zip/pdf2html.zip

# Cleanup
rm -rf /tmp/pdf2html-zip-build /tmp/pdf2html.zip
```

### requirements-zip.txt
```
Pillow==12.2.0
boto3>=1.37.11
botocore>=1.37.11
beautifulsoup4==4.13.4
bs4==0.0.2
pydantic==2.11.3
defusedcsv==2.0.0
Flask==3.1.3
PyYaml==6.0.2
pypdf==6.10.2
urllib3==2.7.0
```

---

## Building pre-remediation-checker.zip / post-remediation-checker.zip

Both use the same requirements. Build process is identical, just different source directories.

```bash
LAMBDA_DIR="lambda/pre-remediation-accessibility-checker"
ZIP_NAME="pre-remediation-checker"

# Clean build directory
rm -rf /tmp/${ZIP_NAME}-build
mkdir -p /tmp/${ZIP_NAME}-build

# Install dependencies
pip3 install --no-cache-dir \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  -r ${LAMBDA_DIR}/requirements.txt \
  -t /tmp/${ZIP_NAME}-build/

# Copy source
cp ${LAMBDA_DIR}/main.py /tmp/${ZIP_NAME}-build/

# Create zip
cd /tmp/${ZIP_NAME}-build
zip -r -q /tmp/${ZIP_NAME}.zip .

# Deploy
cp /tmp/${ZIP_NAME}.zip <DEPLOYMENTS_REPO>/terraform/dxe-prod/pdf-accessibility/lambda/zip/${ZIP_NAME}.zip

# Cleanup
rm -rf /tmp/${ZIP_NAME}-build /tmp/${ZIP_NAME}.zip
```

Repeat with `LAMBDA_DIR=".../post-remediation-accessibility-checker"` and `ZIP_NAME="post-remediation-checker"`.

### requirements.txt (pre/post remediation)
```
pdfservices-sdk==4.1.0
urllib3==2.7.0
setuptools>=78.1.1
requests>=2.32.0
```

---

## Building title-generator.zip

```bash
LAMBDA_DIR="lambda/title-generator-lambda"

rm -rf /tmp/title-generator-build
mkdir -p /tmp/title-generator-build

pip3 install --no-cache-dir \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  -r ${LAMBDA_DIR}/requirements.txt \
  -t /tmp/title-generator-build/

cp ${LAMBDA_DIR}/title_generator.py /tmp/title-generator-build/

cd /tmp/title-generator-build
zip -r -q /tmp/title-generator.zip .

cp /tmp/title-generator.zip <DEPLOYMENTS_REPO>/terraform/dxe-prod/pdf-accessibility/lambda/zip/title-generator.zip

rm -rf /tmp/title-generator-build /tmp/title-generator.zip
```

### requirements.txt (title-generator)
```
PyMuPDF==1.24.14
urllib3==2.7.0
```

---

## Building pdf-splitter.zip

```bash
LAMBDA_DIR="lambda/pdf-splitter-lambda"

rm -rf /tmp/pdf-splitter-build
mkdir -p /tmp/pdf-splitter-build

pip3 install --no-cache-dir \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  -r ${LAMBDA_DIR}/requirements.txt \
  -t /tmp/pdf-splitter-build/

cp ${LAMBDA_DIR}/main.py /tmp/pdf-splitter-build/

cd /tmp/pdf-splitter-build
zip -r -q /tmp/pdf-splitter.zip .

cp /tmp/pdf-splitter.zip <DEPLOYMENTS_REPO>/terraform/dxe-prod/pdf-accessibility/lambda/zip/pdf-splitter.zip

rm -rf /tmp/pdf-splitter-build /tmp/pdf-splitter.zip
```

### requirements.txt (pdf-splitter)
```
PyMuPDF==1.24.14
urllib3==2.7.0
```

---

## PDF Merger (Java)

The pdf-merger Lambda uses a Java JAR, not a Python zip.

```bash
cd lambda/pdf-merger-lambda/PDFMergerLambda
mvn clean package -q -DskipTests

cp target/PDFMergerLambda-1.0-SNAPSHOT.jar \
  <DEPLOYMENTS_REPO>/terraform/dxe-prod/pdf-accessibility/lambda/pdf-merger/PDFMergerLambda-1.0-SNAPSHOT.jar
```

---

## After Building

1. Run `terraform apply` in the deployments repo to push updated zips to Lambda
2. Terraform detects changes via `filebase64sha256()` on the zip files

---

## Key Notes

- Always use `--platform manylinux2014_x86_64` and `--only-binary=:all:` to get Linux-compatible wheels (you're building on macOS)
- Pin dependency versions to avoid surprise upgrades
- Max zip size: 50MB (direct upload), 250MB unzipped
- When updating dependencies for security fixes, update the requirements file and rebuild
