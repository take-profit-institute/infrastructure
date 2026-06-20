# ---------------------------------------------------------------------------
# Route53 호스티드 존 (신규) + CloudFront용 ACM 인증서 (us-east-1, DNS 검증)
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "this" {
  name = var.zone_name
  tags = var.tags
}

resource "aws_acm_certificate" "cf" {
  provider = aws.us_east_1

  domain_name               = var.aliases[0]
  subject_alternative_names = slice(var.aliases, 1, length(var.aliases))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cf.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cf" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cf.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ── WebSocket용 regional ACM (인터넷 ALB가 사용) ──────────────────
resource "aws_acm_certificate" "ws" {
  count = var.ws_domain != "" ? 1 : 0

  domain_name       = var.ws_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "ws_cert_validation" {
  for_each = var.ws_domain != "" ? {
    for dvo in aws_acm_certificate.ws[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "ws" {
  count = var.ws_domain != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.ws[0].arn
  validation_record_fqdns = [for r in aws_route53_record.ws_cert_validation : r.fqdn]
}
