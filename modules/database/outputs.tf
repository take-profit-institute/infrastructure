output "endpoint" {
  description = "RDS 엔드포인트 (host:port)"
  value       = module.rds.db_instance_endpoint
}

output "address" {
  description = "RDS host (포트 제외)"
  value       = module.rds.db_instance_address
}

output "port" {
  value = 5432
}

output "master_username" {
  value = var.master_username
}

output "master_password" {
  description = "postgres-init 모듈에 전달 (provider 인증용)"
  value       = random_password.master.result
  sensitive   = true
}

output "security_group_id" {
  value = aws_security_group.rds.id
}

# postgres-init 모듈로 넘길 서비스별 자격증명 (이름/비번 분리 — for_each 키 제약)
output "service_database_names" {
  description = "비민감 — postgres-init의 for_each 키로 사용"
  value       = var.service_databases
}

output "service_passwords" {
  description = "{ db_name = password } (민감)"
  value       = { for db in var.service_databases : db => random_password.service[db].result }
  sensitive   = true
}

output "master_secret_arn" {
  value = aws_secretsmanager_secret.master.arn
}

output "service_secret_arns" {
  description = "IRSA 정책에서 서비스별 secret 읽기 권한 부여에 사용"
  value       = { for k, s in aws_secretsmanager_secret.service : k => s.arn }
}

# ── Debezium ───────────────────────────────────────────────────────
output "debezium_username" {
  value = var.debezium_username
}

output "debezium_password" {
  value     = random_password.debezium.result
  sensitive = true
}

output "debezium_secret_arn" {
  description = "Debezium 런타임(IRSA)이 읽을 replication 자격증명"
  value       = aws_secretsmanager_secret.debezium.arn
}
