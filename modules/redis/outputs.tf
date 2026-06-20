output "primary_endpoint" {
  description = "쓰기용 primary 엔드포인트"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "읽기용 reader 엔드포인트"
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "port" {
  value = 6379
}
