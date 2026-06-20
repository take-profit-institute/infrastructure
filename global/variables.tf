variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "github_org" {
  description = "GitHub org/유저명"
  type        = string
  default     = "candle"
}

variable "ci_app_repos" {
  description = "ECR push/정적배포를 하는 앱 repo (백엔드 micro-services, webapp)"
  type        = list(string)
  default     = ["micro-services", "webapp"]
}

variable "ci_infra_repo" {
  description = "Terraform plan을 돌리는 repo"
  type        = string
  default     = "infrastructure"
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
