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

  jwt_issuer   = var.edge_jwt_issuer
  jwt_audience = var.edge_jwt_audience

  mesh_nlb_listener_arn = var.edge_mesh_nlb_listener_arn

  cors_allow_origins = var.edge_cors_allow_origins

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
  allowed_cidrs   = var.admin_allowed_cidrs

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
