output "route53_zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "route53_zone_arn" {
  description = "external-dns 등에 위임할 zone ARN"
  value       = aws_route53_zone.this.arn
}

output "route53_name_servers" {
  description = "도메인 등록기관에 등록할 NS 레코드"
  value       = aws_route53_zone.this.name_servers
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "api_endpoint" {
  description = "APIGW 기본 invoke URL (CloudFront origin)"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "vpc_link_id" {
  value = aws_apigatewayv2_vpc_link.this.id
}

output "vpc_link_security_group_id" {
  description = "메시 NLB가 이 SG로부터의 인바운드를 허용해야 함"
  value       = aws_security_group.vpc_link.id
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.cf.arn
}
