output "state_bucket_name" {
  description = "envs backend.tf의 bucket 값으로 사용"
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "envs backend.tf의 dynamodb_table 값으로 사용"
  value       = aws_dynamodb_table.locks.name
}

output "region" {
  value = var.region
}
