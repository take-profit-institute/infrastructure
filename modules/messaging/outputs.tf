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
