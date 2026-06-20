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

  enable_external_dns = false # Phase 5(Route53) 후 활성화

  tags = local.tags
}
