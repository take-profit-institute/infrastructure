output "lb_controller_role_arn" {
  value = module.lb_controller_irsa.iam_role_arn
}

output "external_secrets_role_arn" {
  value = module.external_secrets_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  value = var.enable_external_dns ? module.external_dns_irsa[0].iam_role_arn : null
}

output "argocd_namespace" {
  value = helm_release.argocd.namespace
}
