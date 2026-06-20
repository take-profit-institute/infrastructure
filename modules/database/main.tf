# ---------------------------------------------------------------------------
# Database 모듈 — 단일 PostgreSQL(RDS) 인스턴스
# 서비스별 DB 분리(option a)는 postgres-init 모듈에서 생성한다.
# 이 모듈은 인스턴스 + 보안그룹 + Secrets Manager(자격증명)만 책임진다.
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "Postgres access for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  dynamic "ingress" {
    for_each = length(var.allowed_security_group_ids) > 0 ? [1] : []
    content {
      description     = "PostgreSQL from allowed SGs"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = var.allowed_security_group_ids
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.7"

  identifier = "${var.name}-postgres"

  engine               = "postgres"
  engine_version       = var.engine_version
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true

  # 초기 관리용 DB(placeholder). 실제 서비스 DB는 postgres-init가 생성.
  db_name  = "candle"
  username = var.master_username
  port     = 5432

  # 마스터 비번은 우리가 random_password로 생성해 Secrets Manager에 저장한다.
  manage_master_user_password = false
  password                    = random_password.master.result

  multi_az               = var.multi_az
  db_subnet_group_name   = var.database_subnet_group_name
  create_db_subnet_group = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible

  # CDC: Debezium이 WAL을 logical decoding으로 읽을 수 있게 한다.
  create_db_parameter_group = true
  parameter_group_name      = "${var.name}-postgres16"
  parameters = var.logical_replication ? [
    {
      name         = "rds.logical_replication"
      value        = "1"
      apply_method = "pending-reboot"
    },
    {
      name         = "max_replication_slots"
      value        = "10"
      apply_method = "pending-reboot"
    },
    {
      name         = "max_wal_senders"
      value        = "10"
      apply_method = "pending-reboot"
    },
  ] : []

  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  performance_insights_enabled = true

  tags = var.tags
}
