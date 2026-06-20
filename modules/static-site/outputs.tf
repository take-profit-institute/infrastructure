output "bucket_name" {
  description = "CI가 빌드 산출물을 업로드할 S3 버킷"
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "CI가 캐시 무효화(invalidation)할 CloudFront ID"
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "domain" {
  value = var.domain
}
