variable "name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "subjects" {
  description = "허용할 GitHub sub (예: repo:org/candle-backend:*)"
  type        = list(string)
}

variable "policy_json" {
  description = "인라인 정책 JSON (비우면 미부여)"
  type        = string
  default     = ""
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
