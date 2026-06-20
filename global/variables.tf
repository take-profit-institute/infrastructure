variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "service_repositories" {
  description = "마이크로서비스 + 빌드 산출물별 ECR repo"
  type        = list(string)
  default = [
    "auth",
    "user",
    "trading", # account + trading 통합
    "portfolio",
    "market",
    "ranking",
    "mission",
    "learning",
    "notification",
    "bff",
  ]
}
