variable "name" {
  description = "MSK 클러스터 이름 (예: candle-dev)"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "브로커가 위치할 private 서브넷. number_of_broker_nodes는 이 개수의 배수여야 함"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "Kafka 접근 허용 CIDR (VPC — 여러 서비스/Debezium이 접근)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  type    = list(string)
  default = []
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "broker_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "number_of_broker_nodes" {
  description = "subnet_ids 개수의 배수 (AZ당 1개 이상)"
  type        = number
  default     = 2
}

variable "broker_volume_size" {
  type    = number
  default = 50
}

variable "auto_create_topics" {
  description = "true면 발행 시 토픽 자동 생성 (Debezium outbox 라우터/신규 이벤트에 유연)"
  type        = bool
  default     = true
}

variable "default_replication_factor" {
  type    = number
  default = 2
}

variable "min_insync_replicas" {
  type    = number
  default = 1
}

variable "num_partitions" {
  type    = number
  default = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ── SASL/SCRAM (Debezium/Strimzi 전용) ─────────────────────────────
variable "enable_scram" {
  description = "MSK에 SASL/SCRAM 인증 추가 (Debezium/Strimzi용, IAM과 공존)"
  type        = bool
  default     = false
}

variable "scram_username" {
  description = "Debezium SCRAM 사용자명"
  type        = string
  default     = "debezium"
}
