variable "name" {
  description = "IAM role 이름 (예: candle-dev-trading)"
  type        = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  description = "OIDC issuer URL (https:// 제외)"
  type        = string
}

variable "namespace" {
  description = "ServiceAccount 네임스페이스"
  type        = string
  default     = "candle"
}

variable "service_account" {
  description = "바인딩할 ServiceAccount 이름"
  type        = string
}

variable "secret_arns" {
  description = "읽기 허용할 Secrets Manager secret ARN 목록"
  type        = list(string)
  default     = []
}

variable "msk_cluster_arn" {
  description = "설정 시 MSK IAM(produce/consume) 권한 부여"
  type        = string
  default     = ""
}

variable "additional_policy_json" {
  description = "추가 인라인 정책 JSON (예: SES 발송 권한)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
