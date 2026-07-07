# ---------------------------------------------------------------------------
# postgres-init — 단일 application DB 안에 서비스별 schema + 전용 role 생성
#
# ⚠️ 이 모듈의 postgresql provider는 RDS 엔드포인트에 네트워크로 도달해야 한다.
#    RDS는 private subnet + publicly_accessible=false 이므로 다음 중 하나가 필요:
#      - SSM 포트포워딩/bastion 으로 터널 후 apply
#      - VPC 내부(예: CI 러너, EKS Job)에서 apply
#    연결이 안 되는 환경에서는 -target 으로 database 모듈만 먼저 apply 한다.
# ---------------------------------------------------------------------------

# 서비스별 로그인 role (비번은 Secrets Manager 값과 동일)
resource "postgresql_role" "service" {
  for_each = toset(var.schema_names)

  name     = each.key
  login    = true
  password = var.passwords[each.key]
}

# 서비스별 schema (소유자 = 해당 role)
resource "postgresql_schema" "service" {
  for_each = toset(var.schema_names)

  database = var.database_name
  name     = each.key
  owner    = postgresql_role.service[each.key].name
}

locals {
  # trading-service는 기존 migration에서 도메인별 schema를 명시적으로 사용한다.
  extra_schema_owners = {
    account     = "trading"
    order_svc   = "trading"
    reservation = "trading"
  }
}

resource "postgresql_schema" "extra" {
  for_each = local.extra_schema_owners

  database = var.database_name
  name     = each.key
  owner    = postgresql_role.service[each.value].name
}

# 서비스 role은 공유 DB에 접속 가능하고, 자기 schema를 search_path 기본값으로 쓴다.
# CREATE: 각 서비스 Flyway 마이그레이션 첫 줄이 'CREATE SCHEMA IF NOT EXISTS <svc>'라
# DB 레벨 CREATE 권한이 필요하다(PG는 IF NOT EXISTS여도 CREATE 권한을 먼저 검사).
resource "postgresql_grant" "service_connect" {
  for_each = toset(var.schema_names)

  role        = postgresql_role.service[each.key].name
  database    = var.database_name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE"]
}

resource "postgresql_grant" "service_schema" {
  for_each = toset(var.schema_names)

  role        = postgresql_role.service[each.key].name
  database    = var.database_name
  schema      = postgresql_schema.service[each.key].name
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_grant" "extra_schema" {
  for_each = local.extra_schema_owners

  role        = postgresql_role.service[each.value].name
  database    = var.database_name
  schema      = postgresql_schema.extra[each.key].name
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_default_privileges" "service_tables" {
  for_each = toset(var.schema_names)

  role        = postgresql_role.service[each.key].name
  owner       = postgresql_role.service[each.key].name
  database    = var.database_name
  schema      = postgresql_schema.service[each.key].name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

resource "postgresql_default_privileges" "service_sequences" {
  for_each = toset(var.schema_names)

  role        = postgresql_role.service[each.key].name
  owner       = postgresql_role.service[each.key].name
  database    = var.database_name
  schema      = postgresql_schema.service[each.key].name
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}

resource "postgresql_default_privileges" "extra_tables" {
  for_each = local.extra_schema_owners

  role        = postgresql_role.service[each.value].name
  owner       = postgresql_role.service[each.value].name
  database    = var.database_name
  schema      = postgresql_schema.extra[each.key].name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

resource "postgresql_default_privileges" "extra_sequences" {
  for_each = local.extra_schema_owners

  role        = postgresql_role.service[each.value].name
  owner       = postgresql_role.service[each.value].name
  database    = var.database_name
  schema      = postgresql_schema.extra[each.key].name
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}

resource "postgresql_extension" "pg_trgm" {
  name     = "pg_trgm"
  database = var.database_name
  schema   = "public"
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
  count = var.create_debezium_role ? 1 : 0

  role        = postgresql_role.debezium[0].name
  database    = var.database_name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "debezium_schema_usage" {
  for_each = var.create_debezium_role ? toset(var.schema_names) : toset([])

  role        = postgresql_role.debezium[0].name
  database    = var.database_name
  schema      = postgresql_schema.service[each.key].name
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "debezium_extra_schema_usage" {
  for_each = var.create_debezium_role ? local.extra_schema_owners : {}

  role        = postgresql_role.debezium[0].name
  database    = var.database_name
  schema      = postgresql_schema.extra[each.key].name
  object_type = "schema"
  privileges  = ["USAGE"]
}
