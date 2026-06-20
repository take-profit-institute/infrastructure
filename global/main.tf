# 환경 공통 리소스 (dev/prod가 함께 사용)

module "ecr" {
  source = "../modules/ecr"

  repository_names = var.service_repositories
  namespace        = "candle"

  tags = {
    Project = "candle"
    Scope   = "global"
  }
}
