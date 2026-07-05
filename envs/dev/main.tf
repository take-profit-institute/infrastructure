locals {
  name = "candle-${var.environment}"
  tags = {
    Project     = "candle"
    Environment = var.environment
  }
}

# ── Phase 1: Network ───────────────────────────────────────────────
module "network" {
  source = "../../modules/network"

  name               = local.name
  cidr               = var.vpc_cidr
  azs                = var.azs
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets
  single_nat_gateway = var.single_nat_gateway

  tags = local.tags
}

# ── Phase 2: Database (단일 RDS + 단일 DB + 서비스별 schema 분리) ─
module "database" {
  source = "../../modules/database"

  name                       = local.name
  environment                = var.environment
  vpc_id                     = module.network.vpc_id
  database_subnet_group_name = module.network.database_subnet_group_name
  allowed_cidr_blocks        = [module.network.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]

  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot

  tags = local.tags
}

# 서비스별 schema + role 생성 (postgresql provider가 RDS에 도달 가능할 때만 apply)
module "postgres_init" {
  source = "../../modules/postgres-init"

  providers = {
    postgresql = postgresql
  }

  database_name = module.database.application_database_name
  schema_names  = module.database.service_schema_names
  passwords     = module.database.service_passwords

  debezium_username = module.database.debezium_username
  debezium_password = module.database.debezium_password
}

# Market 시계열 DB 자격증명 (TimescaleDB는 candle-k8s가 EKS StatefulSet으로 배포)
module "timescale" {
  source = "../../modules/timescale"

  environment = var.environment
  tags        = local.tags
}

# ── Phase 2: Redis (시세 캐시 / Ranking) ──────────────────────────
module "redis_price_cache" {
  source = "../../modules/redis"

  name                       = "${local.name}-price-cache"
  description                = "Market 시세 캐시 (TTL 1s)"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.database_subnets
  allowed_cidr_blocks        = [module.network.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]

  node_type                = var.redis_node_type
  num_cache_clusters       = var.redis_num_nodes
  automatic_failover       = var.redis_automatic_failover
  multi_az                 = var.redis_multi_az
  maxmemory_policy         = "allkeys-lru" # 캐시: 메모리 차면 LRU 제거
  snapshot_retention_limit = 0             # 순수 캐시 — 백업 불필요

  tags = local.tags
}

module "redis_market_pubsub" {
  source = "../../modules/redis"

  name                       = "${local.name}-market-pubsub"
  description                = "Market 실시간 시세 Pub/Sub (캐시 아님 — BFF가 sub → WebSocket)"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.database_subnets
  allowed_cidr_blocks        = [module.network.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]

  node_type                = var.redis_node_type
  num_cache_clusters       = var.redis_num_nodes
  automatic_failover       = var.redis_automatic_failover
  multi_az                 = var.redis_multi_az
  maxmemory_policy         = "noeviction" # pub/sub은 keyspace 미사용
  snapshot_retention_limit = 0            # 메시지 영속 불필요

  tags = local.tags
}

module "redis_ranking" {
  source = "../../modules/redis"

  name                       = "${local.name}-ranking"
  description                = "Ranking 리더보드 (Sorted Set)"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.database_subnets
  allowed_cidr_blocks        = [module.network.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]

  node_type                = var.redis_node_type
  num_cache_clusters       = var.redis_num_nodes
  automatic_failover       = var.redis_automatic_failover
  multi_az                 = var.redis_multi_az
  maxmemory_policy         = "noeviction" # 랭킹 데이터 보존
  snapshot_retention_limit = var.redis_ranking_snapshot_retention

  tags = local.tags
}

# ── Phase 2: MSK (Kafka) — Debezium CDC outbox + 서비스 이벤트 ─────
module "messaging" {
  source = "../../modules/messaging"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnets
  allowed_cidr_blocks        = [module.network.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]

  broker_instance_type   = var.msk_broker_instance_type
  number_of_broker_nodes = length(var.private_subnets)
  broker_volume_size     = var.msk_broker_volume_size

  tags = local.tags
}

# ── Phase 3+ ──────────────────────────────────────────────────────
# module "eks"       { source = "../../modules/eks"       ... }
# module "platform"  { source = "../../modules/platform"  ... }   # ArgoCD/Istio/관측 helm + Debezium(Strimzi)
# module "edge"      { source = "../../modules/edge"      ... }
