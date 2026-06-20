variable "name" {
  description = "리소스 이름 prefix (예: candle-dev)"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  description = "OIDC issuer URL (https:// 제외)"
  type        = string
}

# ── 토글 / 도메인 ──────────────────────────────────────────────────
variable "enable_external_dns" {
  description = "Route53 zone 준비(Phase 5) 후 활성화"
  type        = bool
  default     = false
}

variable "external_dns_zone_arns" {
  type    = list(string)
  default = ["*"]
}

variable "external_dns_domain_filters" {
  type    = list(string)
  default = []
}

# ── Chart 버전 ─────────────────────────────────────────────────────
variable "lb_controller_chart_version" {
  type    = string
  default = "1.8.1"
}

variable "external_secrets_chart_version" {
  type    = string
  default = "0.10.4"
}

variable "external_dns_chart_version" {
  type    = string
  default = "1.15.0"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.6.12"
}

variable "tags" {
  type    = map(string)
  default = {}
}
