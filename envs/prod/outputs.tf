output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnets" {
  value = module.network.private_subnets
}

output "database_subnet_group_name" {
  value = module.network.database_subnet_group_name
}

output "nat_public_ips" {
  description = "증권사 API 등 외부 화이트리스트 등록용"
  value       = module.network.nat_public_ips
}

output "rds_endpoint" {
  value = module.database.endpoint
}

output "rds_service_secret_arns" {
  description = "서비스별 DB 자격증명 secret ARN (IRSA 정책에서 참조)"
  value       = module.database.service_secret_arns
}

output "redis_price_cache_endpoint" {
  value = module.redis_price_cache.primary_endpoint
}

output "redis_ranking_endpoint" {
  value = module.redis_ranking.primary_endpoint
}

output "redis_market_pubsub_endpoint" {
  description = "BFF가 sub할 Market 실시간 Pub/Sub 엔드포인트"
  value       = module.redis_market_pubsub.primary_endpoint
}

output "redis_chat_pubsub_endpoint" {
  description = "chatting-service가 PUB/SUB·방 카운터에 쓰는 채팅 전용 Pub/Sub 엔드포인트"
  value       = module.redis_chat_pubsub.primary_endpoint
}

output "msk_bootstrap_brokers_iam" {
  value = module.messaging.bootstrap_brokers_sasl_iam
}

output "timescale_secret_arn" {
  value = module.timescale.secret_arn
}

output "debezium_secret_arn" {
  value = module.database.debezium_secret_arn
}

# ── EKS ────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "irsa_app_role_arns" {
  description = "서비스별 IRSA role ARN — candle-k8s의 ServiceAccount 애너테이션에 사용"
  value       = { for k, m in module.irsa_app : k => m.role_arn }
}

output "irsa_market_role_arn" {
  value = module.irsa_market.role_arn
}

output "irsa_notification_role_arn" {
  value = module.irsa_notification.role_arn
}

output "irsa_debezium_role_arn" {
  value = module.irsa_debezium.role_arn
}

# ── Platform ───────────────────────────────────────────────────────
output "argocd_namespace" {
  value = module.platform.argocd_namespace
}

output "lb_controller_role_arn" {
  value = module.platform.lb_controller_role_arn
}

output "external_secrets_role_arn" {
  value = module.platform.external_secrets_role_arn
}

# ── Edge ───────────────────────────────────────────────────────────
output "cloudfront_domain_name" {
  value = var.enable_edge ? module.edge[0].cloudfront_domain_name : null
}

output "route53_name_servers" {
  description = "도메인 등록기관에 등록할 NS"
  value       = var.enable_edge ? module.edge[0].route53_name_servers : null
}

output "edge_api_endpoint" {
  value = var.enable_edge ? module.edge[0].api_endpoint : null
}

output "edge_vpc_link_security_group_id" {
  description = "메시 NLB가 인바운드 허용해야 할 SG"
  value       = var.enable_edge ? module.edge[0].vpc_link_security_group_id : null
}

# ── 정적 사이트 (CI 업로드/무효화 대상) ────────────────────────────
output "admin_bucket" {
  value = var.enable_edge ? module.admin_site[0].bucket_name : null
}

output "admin_distribution_id" {
  value = var.enable_edge ? module.admin_site[0].distribution_id : null
}

output "webapp_bucket" {
  value = var.enable_edge ? module.webapp_site[0].bucket_name : null
}

output "webapp_distribution_id" {
  value = var.enable_edge ? module.webapp_site[0].distribution_id : null
}

output "ws_acm_certificate_arn" {
  description = "candle-k8s WS ALB Ingress 애너테이션에 사용"
  value       = var.enable_edge ? module.edge[0].ws_acm_certificate_arn : null
}
