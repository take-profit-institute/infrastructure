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

variable "jwt_header_claims" {
  description = "JWT 검증 후 백엔드로 주입할 헤더 ↔ 클레임 매핑(헤더명 = 클레임 경로). 클라이언트가 보낸 동일 헤더는 overwrite로 차단(스푸핑 방지). 예: X-Account-Id ← 토큰의 account 클레임"
  type        = map(string)
  default = {
    "X-Account-Id" = "sub" # 실제 Auth 토큰의 account 클레임명으로 교체(예: accountId)
  }
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

variable "cors_allow_origins" {
  description = "APIGW CORS 허용 origin (앱 래핑 — webapp/admin 도메인, capacitor 등). 비우면 CORS 미설정"
  type        = list(string)
  default     = []
}

variable "ws_domain" {
  description = "WebSocket 전용 도메인 (예: ws.candle.io). 설정 시 ALB용 regional ACM 발급. WS는 HTTP API가 아닌 인터넷 ALB(candle-k8s)로 처리"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
