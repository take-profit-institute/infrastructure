output "cluster_arn" {
  value = aws_msk_cluster.this.arn
}

output "bootstrap_brokers_sasl_iam" {
  description = "IAM 인증 부트스트랩 브로커 (서비스/Debezium 접속용)"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_tls" {
  value = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "security_group_id" {
  value = aws_security_group.msk.id
}

output "bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM 부트스트랩 브로커 (Debezium/Strimzi 접속용, 9096)"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
}

output "msk_scram_secret_arn" {
  description = "Debezium SCRAM 시크릿 ARN (Secrets Manager)"
  value       = var.enable_scram ? aws_secretsmanager_secret.msk_scram[0].arn : ""
}

output "msk_scram_secret_name" {
  description = "Debezium SCRAM 시크릿 이름"
  value       = var.enable_scram ? aws_secretsmanager_secret.msk_scram[0].name : ""
}
