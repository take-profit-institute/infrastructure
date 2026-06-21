variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "github_org" {
  description = "GitHub org/유저명"
  type        = string
  default     = "take-profit-institute"
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
  # micro-services Gradle 모듈명과 1:1 (org.profit / *-service), + bff(webapp) + 단일 batch
  default = [
    "auth-service",
    "user-service",
    "market-service",
    "trading-service", # account + trading 통합
    "portfolio-service",
    "ranking-service",
    "mission-service",
    "learning-service",
    "notification-service",
    "bff",
    "batch", # 단일 Spring Batch 모듈 (Job은 --spring.batch.job.name으로 선택)
  ]
}
