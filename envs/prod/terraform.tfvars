# prod 환경 — 가용성 우선 (3 AZ, AZ별 NAT 이중화)
region      = "ap-northeast-2"
environment = "prod"

vpc_cidr = "10.1.0.0/16"
azs      = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]

public_subnets   = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
private_subnets  = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
database_subnets = ["10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"]

single_nat_gateway = false

# Database — prod: Multi-AZ, 백업 길게, 삭제 보호 on
db_instance_class          = "db.r6g.large"
db_allocated_storage       = 100
db_multi_az                = true
db_backup_retention_period = 14
db_deletion_protection     = true
db_skip_final_snapshot     = false

# Redis — prod: 다중 노드 + failover + Multi-AZ
redis_node_type                  = "cache.r7g.large"
redis_num_nodes                  = 2
redis_automatic_failover         = true
redis_multi_az                   = true
redis_ranking_snapshot_retention = 7

# MSK — prod: 브로커 수 = private subnet 수 = 3
msk_broker_instance_type = "kafka.m7g.large"
msk_broker_volume_size   = 100

# EKS — prod: m6i.large 3~8대
kubernetes_version      = "1.30"
eks_node_instance_types = ["m6i.large"]
eks_node_min_size       = 3
eks_node_max_size       = 8
eks_node_desired_size   = 3

# Edge — 도메인 확보 후 enable_edge=true (그 전까지 edge/static/ws 미생성)
enable_edge = true

# 보유 도메인 candle.io.kr. API는 api.* 분리, 정적 사이트가 app.*/admin.* 소유
edge_zone_name = "candle.io.kr"
edge_aliases   = ["api.candle.io.kr"]
admin_domain   = "admin.candle.io.kr"
webapp_domain  = "app.candle.io.kr"

ws_domain = "ws.candle.io.kr"

edge_cors_allow_origins = [
  "https://app.candle.io.kr",
  "https://admin.candle.io.kr",
  "capacitor://localhost",
]
# admin_allowed_cidrs       = ["1.2.3.4/32"]            # 사무실 IP 등으로 제한 권장
# edge_jwt_issuer            = "https://auth.candle.io"  # Auth 배포 후
# edge_mesh_nlb_listener_arn = "arn:aws:..."            # candle-k8s NLB 후
