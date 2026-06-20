variable "environment" {
  type = string
}

variable "db_username" {
  type    = string
  default = "market"
}

variable "db_name" {
  type    = string
  default = "market"
}

variable "service_host" {
  description = "EKS 내부 TimescaleDB 서비스 DNS (candle-k8s가 배포하는 StatefulSet의 Service)"
  type        = string
  default     = "timescaledb.candle.svc.cluster.local"
}

variable "port" {
  type    = number
  default = 5432
}

variable "secret_recovery_window_days" {
  type    = number
  default = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}
