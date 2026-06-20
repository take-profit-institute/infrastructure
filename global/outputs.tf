output "ecr_repository_urls" {
  description = "CI(GitHub Actions)에서 push 대상 URL"
  value       = module.ecr.repository_urls
}

output "ci_deploy_role_arn" {
  description = "앱 CI(micro-services/webapp)가 assume할 role (ECR/S3/CloudFront)"
  value       = module.ci_deploy_role.role_arn
}

output "ci_terraform_role_arn" {
  description = "Terraform plan용 read-only role"
  value       = module.ci_terraform_role.role_arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
