output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  description = "EKS 노드그룹/Pod이 위치할 서브넷"
  value       = module.vpc.private_subnets
}

output "database_subnets" {
  value = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "RDS/ElastiCache가 참조할 subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "nat_public_ips" {
  description = "외부 연동(증권사 API 등) IP 화이트리스트용"
  value       = module.vpc.nat_public_ips
}
