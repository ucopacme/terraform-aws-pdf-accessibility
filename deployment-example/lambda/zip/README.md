# Lambda Zip Files

Place the built Lambda zip packages here before running `terraform apply`.

## Source

All Lambda source code lives in the [PDF_Accessibility](https://github.com/ucopacme/PDF_Accessibility) repo. Pre-built zips are available at:

```
git@github.com:ucopacme/PDF_Accessibility.git → lambda/zip/
```

## Quick Setup

```bash
git clone git@github.com:ucopacme/PDF_Accessibility.git /tmp/PDF_Accessibility
cp /tmp/PDF_Accessibility/lambda/zip/*.zip ./
```

## Required Files

| File | Source in PDF_Accessibility repo |
|------|--------|
| `pdf-splitter.zip` | `lambda/zip/pdf-splitter.zip` |
| `title-generator.zip` | `lambda/zip/title-generator.zip` |
| `pre-remediation-checker.zip` | `lambda/zip/pre-remediation-checker.zip` |
| `post-remediation-checker.zip` | `lambda/zip/post-remediation-checker.zip` |
| `pdf2html.zip` | `lambda/zip/pdf2html.zip` |

## Rebuilding

Only needed when Lambda code changes. See [../../docs/lambda-zip-build-guide.md](../../docs/lambda-zip-build-guide.md) for build instructions.
