output "ecr_repository_urls" {
  description = "CI(GitHub Actions)에서 push 대상 URL"
  value       = module.ecr.repository_urls
}
