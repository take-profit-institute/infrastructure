# ---------------------------------------------------------------------------
# Debezium CDC — outbox 테이블별 publication 사전 생성 + SELECT 부여
#
# candle-k8s 의 KafkaConnector 들은 publication.autocreate.mode=disabled 이므로
# publication 을 여기서 미리 만든다. 이름/테이블은 커넥터의 publication.name /
# table.include.list 와 1:1 로 일치해야 한다(단일 candle DB, 스키마별 outbox_events).
#
# ⚠️ 순서: outbox 테이블은 각 서비스의 Flyway 마이그레이션이 생성한다. 따라서 이 리소스는
#    앱 마이그레이션이 끝난 뒤 create_debezium_publications=true 로 2차 apply 한다.
# ⚠️ 권한: CREATE PUBLICATION ... FOR TABLE 은 provider 접속 role(마스터)이 대상 테이블의
#    소유자이거나 상위 권한이어야 한다. RDS(rds_superuser)에서 실패하면 소유 서비스 role 로
#    수동 생성하거나 소유권을 조정한다.
# ---------------------------------------------------------------------------

locals {
  # publication 이름 → outbox 테이블(schema.table) 목록. candle-k8s 커넥터와 동기화할 것.
  debezium_publications = {
    dbz_pub_auth         = ["auth.outbox_events"]
    dbz_pub_users        = ["users.user_outbox_events"]
    dbz_pub_trading      = ["account.outbox_events", "order_svc.outbox_events", "reservation.outbox_events"]
    dbz_pub_ranking      = ["ranking.ranking_outbox_events"]
    dbz_pub_wishlist     = ["wishlist.outbox_events"]
    dbz_pub_stock        = ["stock.outbox_events"]
    dbz_pub_notification = ["notification.outbox_events"]
  }

  # SELECT 부여 대상 (schema.table) 평탄화 → { "schema.table" = { schema, table } }
  debezium_outbox_tables = var.create_debezium_publications ? {
    for t in flatten(values(local.debezium_publications)) :
    t => { schema = split(".", t)[0], table = split(".", t)[1] }
  } : {}
}

resource "postgresql_publication" "debezium" {
  for_each = var.create_debezium_role && var.create_debezium_publications ? local.debezium_publications : {}

  name     = each.key
  database = var.database_name
  tables   = each.value
}

# 초기 스냅샷/디코딩을 위해 debezium role 에 outbox 테이블 SELECT 부여.
resource "postgresql_grant" "debezium_outbox_select" {
  for_each = var.create_debezium_role && var.create_debezium_publications ? local.debezium_outbox_tables : {}

  role        = postgresql_role.debezium[0].name
  database    = var.database_name
  schema      = each.value.schema
  object_type = "table"
  objects     = [each.value.table]
  privileges  = ["SELECT"]
}
