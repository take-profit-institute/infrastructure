variable "database_name" {
  description = "서비스들이 공유하는 단일 application database"
  type        = string
  default     = "candle"
}

variable "schema_names" {
  description = "생성할 서비스별 schema/role 이름 목록 (비민감 — for_each 키로 사용)"
  type        = list(string)
}

variable "passwords" {
  description = "role별 비밀번호 { db_name = password } (민감)"
  type        = map(string)
  sensitive   = true
}

# ── Debezium CDC ───────────────────────────────────────────────────
variable "create_debezium_role" {
  type    = bool
  default = true
}

variable "debezium_username" {
  type    = string
  default = "debezium"
}

variable "debezium_password" {
  type      = string
  default   = ""
  sensitive = true
}

# outbox 테이블별 Debezium publication 사전 생성 + SELECT 부여.
# ⚠️ outbox 테이블은 각 서비스 Flyway 마이그레이션이 만든다(앱 배포 시점) → 앱 마이그레이션 완료 후
#    2차 pass 로 켠다: terraform apply -var='create_debezium_publications=true'
#    (candle-k8s 커넥터는 publication.autocreate.mode=disabled 로 이 publication 을 참조한다.)
variable "create_debezium_publications" {
  type    = bool
  default = false
}
