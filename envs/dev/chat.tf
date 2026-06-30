# ── 종목 실시간 채팅 (chatting-service) ────────────────────────────
# Pub/Sub 팬아웃 + 방 인원 카운터 전용 Redis. 시세/Ranking과 분리한다.
# 모든 chatting-service 파드가 같은 primary 엔드포인트로 PUB/SUB → 팬아웃 보장
# (ElastiCache replication group = non-cluster mode → 단일 primary).
module "redis_chat_pubsub" {
  source = "../../modules/redis"

  name                       = "${local.name}-chat-pubsub"
  description                = "종목 채팅 Pub/Sub 팬아웃 + 방 인원 카운터 (메시지 비영속)"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.database_subnets
  allowed_cidr_blocks        = [module.network.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]

  node_type                = var.redis_node_type
  num_cache_clusters       = var.redis_num_nodes
  automatic_failover       = var.redis_automatic_failover
  multi_az                 = var.redis_multi_az
  maxmemory_policy         = "noeviction" # 카운터 키(*_count, chat:rooms:*) eviction 금지
  snapshot_retention_limit = 0            # 메시지·카운터 영속 불필요

  tags = local.tags
}

# chatting-service 파드가 ExternalSecret(dbSecret=candle/<env>/chat)로 주입받는 런타임 번들.
# 번들의 JSON 키 = 컨테이너 env 이름. transit_encryption=true 이므로 REDIS_URL은 rediss://.
# AUTH_JWT_HMAC_SECRET은 auth-service 서명 시크릿과 반드시 동일해야 한다(불일치 시 WS 4401).
resource "aws_secretsmanager_secret" "chat" {
  name                    = "candle/${var.environment}/chat"
  description             = "chatting-service runtime config (redis url + jwt hmac)"
  recovery_window_in_days = 0 # 파생 가능한 config 시크릿 — 즉시 재생성 허용
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "chat" {
  secret_id = aws_secretsmanager_secret.chat.id
  secret_string = jsonencode({
    REDIS_URL                 = "rediss://${module.redis_chat_pubsub.primary_endpoint}:${module.redis_chat_pubsub.port}"
    AUTH_JWT_HMAC_SECRET      = var.jwt_hmac_secret
    AUTH_JWT_ISSUER           = var.jwt_issuer
    CHAT_CORS_ALLOWED_ORIGINS = "https://${var.webapp_domain},https://${var.ws_domain}"
  })
}
