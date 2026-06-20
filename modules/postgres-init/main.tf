# ---------------------------------------------------------------------------
# postgres-init — 단일 인스턴스 안에 서비스별 DB + 전용 role 생성 (option a)
#
# ⚠️ 이 모듈의 postgresql provider는 RDS 엔드포인트에 네트워크로 도달해야 한다.
#    RDS는 private subnet + publicly_accessible=false 이므로 다음 중 하나가 필요:
#      - SSM 포트포워딩/bastion 으로 터널 후 apply
#      - VPC 내부(예: CI 러너, EKS Job)에서 apply
#    연결이 안 되는 환경에서는 -target 으로 database 모듈만 먼저 apply 한다.
# ---------------------------------------------------------------------------

# 서비스별 로그인 role (비번은 Secrets Manager 값과 동일)
resource "postgresql_role" "service" {
  for_each = toset(var.database_names)

  name     = each.key
  login    = true
  password = var.passwords[each.key]
}

# 서비스별 DB (소유자 = 해당 role)
resource "postgresql_database" "service" {
  for_each = toset(var.database_names)

  name              = each.key
  owner             = postgresql_role.service[each.key].name
  encoding          = "UTF8"
  lc_collate        = "C"
  lc_ctype          = "C"
  template          = "template0"
  connection_limit  = -1
  allow_connections = true
}

# ── Debezium CDC replication role ──────────────────────────────────
# RDS에서는 REPLICATION 속성을 직접 못 주고 rds_replication 멤버십으로 부여한다.
# 각 DB의 outbox 테이블 SELECT 권한/publication은 outbox 테이블 마이그레이션
# 이후 앱(또는 커넥터 셋업)에서 부여한다.
resource "postgresql_role" "debezium" {
  count = var.create_debezium_role ? 1 : 0

  name     = var.debezium_username
  login    = true
  password = var.debezium_password
}

resource "postgresql_grant_role" "debezium_replication" {
  count = var.create_debezium_role ? 1 : 0

  role       = postgresql_role.debezium[0].name
  grant_role = "rds_replication"
}

# Debezium이 각 서비스 DB에 접속할 수 있도록 CONNECT 부여
resource "postgresql_grant" "debezium_connect" {
  for_each = var.create_debezium_role ? toset(var.database_names) : toset([])

  role        = postgresql_role.debezium[0].name
  database    = postgresql_database.service[each.key].name
  object_type = "database"
  privileges  = ["CONNECT"]
}
