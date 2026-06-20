variable "name" {
  description = "리소스 이름 prefix (예: candle-dev)"
  type        = string
}

variable "region" {
  description = "APIGW execute-api origin 도메인 구성에 사용"
  type        = string
}

variable "zone_name" {
  description = "신규 생성할 Route53 호스티드 존 (예: candle.io)"
  type        = string
}

variable "aliases" {
  description = "CloudFront가 서빙할 FQDN 목록 (ACM SAN + CF aliases + Route53 레코드). zone_name 하위여야 함"
  type        = list(string)
}

variable "vpc_id" {
  type = string
}

variable "vpc_link_subnet_ids" {
  description = "API Gateway VPC Link가 위치할 private 서브넷"
  type        = list(string)
}

# ── JWT (Auth 서비스 발급 토큰) ────────────────────────────────────
variable "jwt_issuer" {
  description = "JWT issuer URL. 비우면 authorizer 미적용(전부 public)"
  type        = string
  default     = ""
}

variable "jwt_audience" {
  type    = list(string)
  default = []
}

# ── 메시 백엔드 (candle-k8s가 만드는 내부 NLB) ─────────────────────
variable "mesh_nlb_listener_arn" {
  description = "Istio ingress 내부 NLB의 리스너 ARN. 설정 시 APIGW 라우트 연결"
  type        = string
  default     = ""
}

# ── Rate Limit / WAF ───────────────────────────────────────────────
variable "throttle_burst_limit" {
  type    = number
  default = 2000
}

variable "throttle_rate_limit" {
  type    = number
  default = 1000
}

variable "waf_rate_limit" {
  description = "5분당 IP별 요청 상한 (WAF rate-based)"
  type        = number
  default     = 10000
}

variable "cloudfront_price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "tags" {
  type    = map(string)
  default = {}
}
