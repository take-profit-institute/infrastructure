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

  tags = local.tags
}
