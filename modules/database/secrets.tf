# ---------------------------------------------------------------------------
# 자격증명: random_password 생성 → Secrets Manager 저장
# 각 서비스는 IRSA로 본인 secret만 읽어 DB 접속한다. (TF state엔 평문 미노출 의도)
# ---------------------------------------------------------------------------

resource "random_password" "master" {
  length  = 24
  special = false # RDS 마스터 비번 호환성 위해 특수문자 제외
}

resource "random_password" "service" {
  for_each = toset(var.service_databases)
  length   = 24
  special  = false
}

resource "random_password" "debezium" {
  length  = 24
  special = false
}

# ── 마스터 자격증명 ────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "master" {
  name                    = "candle/${var.environment}/rds/master"
  description             = "RDS master credentials for ${var.name}"
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    host     = module.rds.db_instance_address
    port     = 5432
    dbname   = "candle"
  })
}

# ── 서비스별 자격증명 (DB 1개 = role 1개 = secret 1개) ─────────────
resource "aws_secretsmanager_secret" "service" {
  for_each                = toset(var.service_databases)
  name                    = "candle/${var.environment}/rds/${each.key}"
  description             = "DB credentials for ${each.key} service"
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "service" {
  for_each  = toset(var.service_databases)
  secret_id = aws_secretsmanager_secret.service[each.key].id
  secret_string = jsonencode({
    username = each.key
    password = random_password.service[each.key].result
    engine   = "postgres"
    host     = module.rds.db_instance_address
    port     = 5432
    dbname   = each.key
  })
}

# ── Debezium CDC 커넥터 자격증명 ───────────────────────────────────
resource "aws_secretsmanager_secret" "debezium" {
  name                    = "candle/${var.environment}/rds/debezium"
  description             = "Debezium CDC replication user for ${var.name}"
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "debezium" {
  secret_id = aws_secretsmanager_secret.debezium.id
  secret_string = jsonencode({
    username = var.debezium_username
    password = random_password.debezium.result
    engine   = "postgres"
    host     = module.rds.db_instance_address
    port     = 5432
  })
}
