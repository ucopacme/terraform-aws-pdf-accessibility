# PDF Merger Lambda

Place `PDFMergerLambda-1.0-SNAPSHOT.jar` here before running `terraform apply`.

## Quick Setup

```bash
git clone git@github.com:ucopacme/PDF_Accessibility.git /tmp/PDF_Accessibility
cp /tmp/PDF_Accessibility/lambda/pdf-merger/PDFMergerLambda-1.0-SNAPSHOT.jar ./
```

## Rebuilding

Only needed when PDF Merger code changes:

```bash
cd PDF_Accessibility/lambda/pdf-merger-lambda/PDFMergerLambda
mvn clean package -q -DskipTests
cp target/PDFMergerLambda-1.0-SNAPSHOT.jar <this-directory>/
```
