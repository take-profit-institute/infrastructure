variable "name" {
  description = "리소스 이름 prefix (예: candle-dev)"
  type        = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "database_subnet_group_name" {
  description = "network 모듈이 만든 DB subnet group"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "RDS 5432 접근 허용 CIDR (보통 VPC CIDR)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "RDS 접근 허용 SG (EKS 노드 SG 등)"
  type        = list(string)
  default     = []
}

variable "application_database_name" {
  description = "서비스들이 공유하는 단일 application database. 서비스 격리는 schema로 한다."
  type        = string
  default     = "candle"
}

variable "service_schemas" {
  description = "단일 application database 안에 생성할 서비스별 schema 목록 (schema당 전용 role 1개)"
  type        = list(string)
  default = [
    "auth",
    "users",
    "trading", # account + trading 통합
    "portfolio",
    "ranking",
    "mission",
    "learning",
    "batch", # Spring Batch JobRepository
    "stock",
    "wishlist",
    "news",
    "notification",
  ]
}

# ── 인스턴스 사이즈/가용성 (dev/prod tfvars로 차등) ────────────────
variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "스토리지 오토스케일링 상한"
  type        = number
  default     = 100
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "publicly_accessible" {
  description = "private subnet 원칙상 false. postgres-init를 로컬에서 돌릴 때만 임시 true 고려"
  type        = bool
  default     = false
}

variable "master_username" {
  type    = string
  default = "candle_admin"
}

# ── CDC / Debezium ─────────────────────────────────────────────────
variable "logical_replication" {
  description = "Debezium CDC를 위한 logical replication 활성화 (wal_level=logical)"
  type        = bool
  default     = true
}

variable "debezium_username" {
  description = "Debezium 커넥터 전용 replication role"
  type        = string
  default     = "debezium"
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager 삭제 복구 기간. dev는 0(즉시 삭제), prod는 7+"
  type        = number
  default     = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}
