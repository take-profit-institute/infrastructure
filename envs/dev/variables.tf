variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "environment" {
  type    = string
  default = "dev"
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
  default = true
}

# ── Database ───────────────────────────────────────────────────────
variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_period" {
  type    = number
  default = 7
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

# ── Redis ──────────────────────────────────────────────────────────
variable "redis_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "redis_num_nodes" {
  type    = number
  default = 1
}

variable "redis_automatic_failover" {
  type    = bool
  default = false
}

variable "redis_multi_az" {
  type    = bool
  default = false
}

variable "redis_ranking_snapshot_retention" {
  type    = number
  default = 1
}

variable "jwt_hmac_secret" {
  description = "auth-service가 JWT(HS256) 서명에 쓰는 HMAC 시크릿. chatting-service가 WS 핸드셰이크 검증에 동일 값을 사용한다(반드시 auth와 일치). tfvars에 두지 말고 TF_VAR_jwt_hmac_secret 등으로 주입."
  type        = string
  sensitive   = true
}

variable "jwt_issuer" {
  description = "JWT issuer. chatting-service가 핸드셰이크에서 iss를 검증한다(auth-service의 AUTH_JWT_ISSUER와 동일해야 함)."
  type        = string
  default     = "candle-auth"
}

# ── MSK ────────────────────────────────────────────────────────────
variable "msk_broker_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "msk_broker_volume_size" {
  type    = number
  default = 50
}

# ── EKS ────────────────────────────────────────────────────────────
variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 4
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
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

variable "edge_jwt_header_claims" {
  description = "JWT 검증 후 백엔드 주입 헤더↔클레임 (헤더명=클레임)"
  type        = map(string)
  default     = { "X-Account-Id" = "sub" }
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

# ── Edge / 정적 사이트 ─────────────────────────────────────────────
variable "enable_edge" {
  description = "도메인 확보 후 true. false면 CloudFront/APIGW/ACM/Route53/static-site/external-dns 생성 안 함(나머지 인프라는 정상 apply)"
  type        = bool
  default     = false
}

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
