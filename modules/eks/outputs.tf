output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "IRSA 신뢰관계용 OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "OIDC issuer URL (https:// 제외) — IRSA sub/aud 조건용"
  value       = module.eks.oidc_provider
}

output "cluster_security_group_id" {
  description = "EKS가 생성한 클러스터 SG"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "노드 SG — RDS/Redis/MSK ingress 허용에 사용"
  value       = module.eks.node_security_group_id
}
