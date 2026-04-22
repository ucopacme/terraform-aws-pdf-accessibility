output "bucket_name" {
  value = aws_s3_bucket.pdf_processing.id
}

output "bucket_arn" {
  value = aws_s3_bucket.pdf_processing.arn
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.pdf_remediation.arn
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.pdf_remediation.arn
}

output "vpc_id" {
  value = aws_vpc.pdf_processing.id
}
