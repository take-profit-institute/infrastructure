# ---------------------------------------------------------------------------
# API Gateway (HTTP API) — 라우팅 · JWT 검증 · Rate Limit
# VPC Link로 메시 내부 NLB(candle-k8s)에 연결.
# ---------------------------------------------------------------------------

locals {
  jwt_enabled         = var.jwt_issuer != ""
  integration_enabled = var.mesh_nlb_listener_arn != ""
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name}-api"
  protocol_type = "HTTP"

  # 앱 래핑(WebView/Capacitor)·정적 webapp origin 허용
  dynamic "cors_configuration" {
    for_each = length(var.cors_allow_origins) > 0 ? [1] : []
    content {
      allow_origins     = var.cors_allow_origins
      allow_methods     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
      allow_headers     = ["authorization", "content-type", "x-account-id"]
      allow_credentials = true
      max_age           = 3600
    }
  }

  tags = var.tags
}

# JWT authorizer (Auth 서비스 발급 토큰 검증)
resource "aws_apigatewayv2_authorizer" "jwt" {
  count = local.jwt_enabled ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "jwt"

  jwt_configuration {
    audience = var.jwt_audience
    issuer   = var.jwt_issuer
  }
}

# ── VPC Link → 메시 내부 NLB ───────────────────────────────────────
resource "aws_security_group" "vpc_link" {
  name        = "${var.name}-apigw-vpclink"
  description = "API Gateway VPC Link"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.name}-vpclink"
  subnet_ids         = var.vpc_link_subnet_ids
  security_group_ids = [aws_security_group.vpc_link.id]
  tags               = var.tags
}

# 메시 NLB 리스너가 준비되면(candle-k8s) 연결
resource "aws_apigatewayv2_integration" "mesh" {
  count = local.integration_enabled ? 1 : 0

  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.mesh_nlb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.this.id
}

# /auth/* — 로그인 등 public (JWT 미적용)
resource "aws_apigatewayv2_route" "auth" {
  count = local.integration_enabled ? 1 : 0

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.mesh[0].id}"
}

# 그 외 전부 — JWT 보호 (issuer 설정 시)
resource "aws_apigatewayv2_route" "default" {
  count = local.integration_enabled ? 1 : 0

  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.mesh[0].id}"
  authorization_type = local.jwt_enabled ? "JWT" : "NONE"
  authorizer_id      = local.jwt_enabled ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId     = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      routeKey      = "$context.routeKey"
      status        = "$context.status"
      responseLat   = "$context.responseLatency"
      integrationSt = "$context.integration.status"
    })
  }

  tags = var.tags
}
