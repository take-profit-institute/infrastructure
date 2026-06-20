# ── Phase 5: Edge (CloudFront + WAF + API Gateway + Route53/ACM) ───
# 흐름: Client → CloudFront(WAF) → API Gateway(JWT·RateLimit) → VPC Link
#       → Istio ingress NLB(candle-k8s) → mesh
module "edge" {
  source = "../../modules/edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                = local.name
  region              = var.region
  zone_name           = var.edge_zone_name
  aliases             = var.edge_aliases
  vpc_id              = module.network.vpc_id
  vpc_link_subnet_ids = module.network.private_subnets

  # Auth 서비스 배포(candle-k8s) 후 issuer 설정 → JWT 검증 활성화
  jwt_issuer   = var.edge_jwt_issuer
  jwt_audience = var.edge_jwt_audience

  # Istio ingress 내부 NLB 생성(candle-k8s) 후 리스너 ARN 주입 → 라우트 연결
  mesh_nlb_listener_arn = var.edge_mesh_nlb_listener_arn

  # 앱 래핑·정적 webapp용 CORS 허용 origin
  cors_allow_origins = var.edge_cors_allow_origins

  # WebSocket 전용 도메인 → ALB용 regional ACM 발급
  ws_domain = var.ws_domain

  tags = local.tags
}

# ── 정적 SPA (admin / webapp) — CloudFront + S3 ───────────────────
module "admin_site" {
  source = "../../modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name            = "${local.name}-admin"
  domain          = var.admin_domain
  route53_zone_id = module.edge.route53_zone_id
  allowed_cidrs   = var.admin_allowed_cidrs # 비우면 공개

  tags = local.tags
}

module "webapp_site" {
  source = "../../modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name            = "${local.name}-webapp"
  domain          = var.webapp_domain
  route53_zone_id = module.edge.route53_zone_id

  tags = local.tags
}
