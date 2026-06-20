# ---------------------------------------------------------------------------
# Network 모듈 — terraform-aws-modules/vpc wrapper
# EKS, RDS, ElastiCache, MSK가 모두 이 VPC 안에 들어간다.
# 다이어그램: EKS / Data Layer는 Private Subnet, ALB는 Edge(public).
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = var.name
  cidr = var.cidr

  azs              = var.azs
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  # RDS/ElastiCache가 쓸 전용 서브넷 그룹 생성
  create_database_subnet_group = true

  # NAT: dev는 single(비용↓), prod는 AZ별 이중화
  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # AWS Load Balancer Controller가 서브넷을 자동 탐색하기 위한 태그
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}
