variable "name" {
  description = "ElastiCache 식별자 (예: candle-dev-price-cache)"
  type        = string
}

variable "description" {
  type    = string
  default = "candle redis"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Redis가 위치할 서브넷 (private/database)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "6379 접근 허용 CIDR (보통 VPC CIDR — 여러 서비스가 접근)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  type    = list(string)
  default = []
}

variable "node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "engine_version" {
  type    = string
  default = "7.1"
}

variable "num_cache_clusters" {
  description = "노드 수 (primary 1 + replica N). automatic_failover에는 2 이상"
  type        = number
  default     = 2
}

variable "automatic_failover" {
  type    = bool
  default = true
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "transit_encryption" {
  type    = bool
  default = true
}

variable "snapshot_retention_limit" {
  description = "0이면 백업 없음(순수 캐시), 1+ 면 스냅샷 보관(Ranking 등 영속성)"
  type        = number
  default     = 0
}

variable "maxmemory_policy" {
  description = "캐시는 allkeys-lru, Ranking(Sorted Set)은 noeviction 권장"
  type        = string
  default     = "noeviction"
}

variable "tags" {
  type    = map(string)
  default = {}
}
