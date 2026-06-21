# ── Phase 4: Platform bootstrap (helm) ─────────────────────────────
# Terraform은 부트스트랩(LB Controller / ESO / ArgoCD)까지.
# Istio · Strimzi(Debezium) · 관측 · 마이크로서비스는 ArgoCD(candle-k8s).
module "platform" {
  source = "../../modules/platform"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  name              = local.name
  cluster_name      = module.eks.cluster_name
  region            = var.region
  vpc_id            = module.network.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider

  # WS ALB(candle-k8s)의 ws.<domain> 레코드를 external-dns가 자동 생성
  enable_external_dns         = var.enable_edge
  external_dns_zone_arns      = var.enable_edge ? [module.edge[0].route53_zone_arn] : ["*"]
  external_dns_domain_filters = var.enable_edge ? [var.edge_zone_name] : []

  tags = local.tags
}
