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
