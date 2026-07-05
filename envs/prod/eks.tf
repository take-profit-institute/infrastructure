# ── Phase 3: EKS 클러스터 + 노드그룹 + IRSA ────────────────────────
module "eks" {
  source = "../../modules/eks"

  name               = local.name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnets

  # prod: API 서버 프라이빗. GitOps/CI는 VPC 내부에서 접근.
  endpoint_public_access = false

  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_desired_size   = var.eks_node_desired_size

  tags = local.tags
}

# DB 이름 → k8s ServiceAccount 이름 (users DB는 user 서비스)
locals {
  service_accounts = {
    auth      = "auth-service"
    users     = "user-service"
    trading   = "trading-service"
    portfolio = "portfolio-service"
    ranking   = "ranking-service"
    mission   = "mission-service"
    learning  = "learning-service"
    batch     = "batch" # Spring Batch CronJob SA (JobRepository + MSK)
    stock     = "stock-service"
    wishlist  = "wishlist-service"
    news      = "news-service"
  }

  irsa_app_database_names = setsubtract(toset(module.database.service_database_names), toset(["notification"]))
}

# 서비스별 IRSA: 본인 DB secret 읽기 + MSK IAM(produce/consume)
module "irsa_app" {
  source   = "../../modules/irsa-service"
  for_each = local.irsa_app_database_names

  name              = "${local.name}-${each.key}"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  namespace         = "candle"
  service_account   = local.service_accounts[each.key]
  secret_arns       = [module.database.service_secret_arns[each.key]]
  msk_cluster_arn   = module.messaging.cluster_arn

  tags = local.tags
}

# Market: TimescaleDB secret + MSK
module "irsa_market" {
  source = "../../modules/irsa-service"

  name              = "${local.name}-market"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  namespace         = "candle"
  service_account   = "market-service"
  secret_arns       = [module.timescale.secret_arn]
  msk_cluster_arn   = module.messaging.cluster_arn

  tags = local.tags
}

# Notification: SES 발송 + MSK(이벤트 구독)
module "irsa_notification" {
  source = "../../modules/irsa-service"

  name              = "${local.name}-notification"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  namespace         = "candle"
  service_account   = "notification-service"
  secret_arns       = [module.database.service_secret_arns["notification"]]
  msk_cluster_arn   = module.messaging.cluster_arn

  additional_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })

  tags = local.tags
}

# Debezium(Strimzi KafkaConnect): replication secret + MSK
module "irsa_debezium" {
  source = "../../modules/irsa-service"

  name              = "${local.name}-debezium"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  namespace         = "kafka"
  service_account   = "debezium-connect"
  secret_arns       = [module.database.debezium_secret_arn]
  msk_cluster_arn   = module.messaging.cluster_arn

  tags = local.tags
}
