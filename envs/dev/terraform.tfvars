# dev 환경 — 비용 절감 우선 (작은 사이즈, single NAT)
region      = "ap-northeast-2"
environment = "dev"

vpc_cidr = "10.0.0.0/16"
azs      = ["ap-northeast-2a", "ap-northeast-2c"]

public_subnets   = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnets  = ["10.0.10.0/24", "10.0.11.0/24"]
database_subnets = ["10.0.20.0/24", "10.0.21.0/24"]

single_nat_gateway = true

# Database — dev: 작게, 백업 짧게, 삭제 보호 off
db_instance_class          = "db.t4g.medium"
db_allocated_storage       = 20
db_multi_az                = false
db_backup_retention_period = 1
db_deletion_protection     = false
db_skip_final_snapshot     = true

# Redis — dev: 단일 노드, failover 없음
redis_node_type                  = "cache.t4g.small"
redis_num_nodes                  = 1
redis_automatic_failover         = false
redis_multi_az                   = false
redis_ranking_snapshot_retention = 1

# MSK — dev: 작은 브로커 (브로커 수 = private subnet 수 = 2)
msk_broker_instance_type = "kafka.t3.small"
msk_broker_volume_size   = 50

# EKS — dev: 작은 노드 2~4대
kubernetes_version      = "1.30"
eks_node_instance_types = ["t3.large"]
eks_node_min_size       = 2
eks_node_max_size       = 4
eks_node_desired_size   = 2

# Edge — 실제 보유 도메인으로 교체할 것
edge_zone_name = "dev.candle.io"
edge_aliases   = ["dev.candle.io", "app.dev.candle.io"]
# edge_jwt_issuer            = "https://auth.dev.candle.io"   # Auth 배포 후
# edge_mesh_nlb_listener_arn = "arn:aws:..."                  # candle-k8s NLB 후
