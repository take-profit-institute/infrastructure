# ---------------------------------------------------------------------------
# Timescale 모듈 — Market 시계열 DB 자격증명 (Secrets Manager)
#
# TimescaleDB 자체는 EKS StatefulSet으로 candle-k8s(ArgoCD/Helm)에서 배포한다.
# (예: timescale/timescaledb-single 차트, gp3 EBS PVC)
# 여기서는 비밀번호만 생성/저장하고, External Secrets Operator(IRSA)가
# 이 secret을 k8s Secret으로 동기화 → StatefulSet과 Market 서비스가 함께 사용.
#
# RDS와 분리된 별도 인스턴스이므로 host는 클러스터 내부 Service DNS다.
# ---------------------------------------------------------------------------

resource "random_password" "market" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "market" {
  name                    = "candle/${var.environment}/timescale/market"
  description             = "TimescaleDB credentials for Market service (EKS StatefulSet)"
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "market" {
  secret_id = aws_secretsmanager_secret.market.id
  secret_string = jsonencode({
    username                   = var.db_username
    password                   = random_password.market.result
    engine                     = "timescaledb"
    host                       = var.service_host
    port                       = var.port
    dbname                     = var.db_name
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${var.service_host}:${var.port}/${var.db_name}"
    SPRING_DATASOURCE_USERNAME = var.db_username
    SPRING_DATASOURCE_PASSWORD = random_password.market.result
    MARKET_DB_URL              = "jdbc:postgresql://${var.service_host}:${var.port}/${var.db_name}"
    MARKET_DB_USERNAME         = var.db_username
    MARKET_DB_PASSWORD         = random_password.market.result
    POSTGRES_USER              = var.db_username
    POSTGRES_PASSWORD          = random_password.market.result
  })
}
