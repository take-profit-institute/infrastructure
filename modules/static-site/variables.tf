variable "name" {
  description = "리소스 이름/버킷 prefix (예: candle-dev-admin). S3 버킷명은 전역 유일"
  type        = string
}

variable "domain" {
  description = "서빙 도메인 (예: admin.candle.io)"
  type        = string
}

variable "route53_zone_id" {
  description = "edge 모듈이 만든 호스티드 존 ID"
  type        = string
}

variable "index_document" {
  type    = string
  default = "index.html"
}

variable "spa" {
  description = "SPA 라우팅 — 403/404를 index.html로 (클라이언트 라우터)"
  type        = bool
  default     = true
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "allowed_cidrs" {
  description = "설정 시 WAF로 해당 IP만 허용 (admin 접근제한용). 비우면 공개"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
