variable "repository_names" {
  description = "생성할 컨테이너 이미지 repo 목록 (마이크로서비스별)"
  type        = list(string)
}

variable "namespace" {
  description = "repo 이름 prefix (예: candle → candle/auth)"
  type        = string
  default     = "candle"
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "untagged_expire_days" {
  description = "태그 없는 이미지 만료일"
  type        = number
  default     = 14
}

variable "max_tagged_images" {
  description = "태그된 이미지 보관 개수"
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
