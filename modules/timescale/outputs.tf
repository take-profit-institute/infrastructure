output "secret_arn" {
  description = "Market TimescaleDB 자격증명 secret ARN (IRSA/ESO에서 참조)"
  value       = aws_secretsmanager_secret.market.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.market.name
}
