variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "database_subnets" {
  type = list(string)
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

# ── Database ───────────────────────────────────────────────────────
variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_allocated_storage" {
  type    = number
  default = 100
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_backup_retention_period" {
  type    = number
  default = 14
}

variable "db_deletion_protection" {
  type    = bool
  default = true
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = false
}

# ── Redis ──────────────────────────────────────────────────────────
variable "redis_node_type" {
  type    = string
  default = "cache.r7g.large"
}

variable "redis_num_nodes" {
  type    = number
  default = 2
}

variable "redis_automatic_failover" {
  type    = bool
  default = true
}

variable "redis_multi_az" {
  type    = bool
  default = true
}

variable "redis_ranking_snapshot_retention" {
  type    = number
  default = 7
}

# ── MSK ────────────────────────────────────────────────────────────
variable "msk_broker_instance_type" {
  type    = string
  default = "kafka.m7g.large"
}

variable "msk_broker_volume_size" {
  type    = number
  default = 100
}

# ── EKS ────────────────────────────────────────────────────────────
variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "eks_node_min_size" {
  type    = number
  default = 3
}

variable "eks_node_max_size" {
  type    = number
  default = 8
}

variable "eks_node_desired_size" {
  type    = number
  default = 3
}

# ── Edge ───────────────────────────────────────────────────────────
variable "edge_zone_name" {
  description = "신규 Route53 호스티드 존 도메인"
  type        = string
}

variable "edge_aliases" {
  description = "CloudFront 서빙 FQDN 목록 (zone_name 하위)"
  type        = list(string)
}

variable "edge_jwt_issuer" {
  type    = string
  default = ""
}

variable "edge_jwt_audience" {
  type    = list(string)
  default = []
}

variable "edge_mesh_nlb_listener_arn" {
  description = "candle-k8s가 만드는 Istio ingress NLB 리스너 ARN (준비 후 주입)"
  type        = string
  default     = ""
}

variable "edge_cors_allow_origins" {
  type    = list(string)
  default = []
}

variable "ws_domain" {
  description = "WebSocket 전용 도메인"
  type        = string
  default     = ""
}

# ── 정적 사이트 ────────────────────────────────────────────────────
variable "admin_domain" {
  type = string
}

variable "webapp_domain" {
  type = string
}

variable "admin_allowed_cidrs" {
  description = "admin 접근 허용 IP (비우면 공개)"
  type        = list(string)
  default     = []
}
