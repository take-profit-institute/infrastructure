# ---------------------------------------------------------------------------
# Messaging 모듈 — Amazon MSK (Kafka)
# 인증: IAM (SASL/IAM) + 전송구간 TLS. 서비스/Debezium은 IRSA로 IAM 인증.
# Debezium(CDC outbox)이 발행하는 토픽 + 여러 서비스가 구독.
# ---------------------------------------------------------------------------

resource "aws_security_group" "msk" {
  name        = "${var.name}-msk"
  description = "Kafka access for ${var.name}"
  vpc_id      = var.vpc_id

  # 9092 plaintext / 9094 TLS / 9098 IAM
  ingress {
    description = "Kafka from VPC"
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  dynamic "ingress" {
    for_each = length(var.allowed_security_group_ids) > 0 ? [1] : []
    content {
      description     = "Kafka from allowed SGs"
      from_port       = 9092
      to_port         = 9098
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

resource "aws_msk_configuration" "this" {
  name           = "${var.name}-config"
  kafka_versions = [var.kafka_version]

  server_properties = <<-PROPERTIES
    auto.create.topics.enable=${var.auto_create_topics}
    default.replication.factor=${var.default_replication_factor}
    min.insync.replicas=${var.min_insync_replicas}
    num.partitions=${var.num_partitions}
    delete.topic.enable=true
  PROPERTIES
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_volume_size
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
      # SCRAM은 Strimzi/Debezium 커넥트 전용(Strimzi가 IAM auth 미지원). IAM과 공존.
      scram = var.enable_scram
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# SASL/SCRAM 인증 (Debezium/Strimzi 전용) — enable_scram=true 일 때만 생성
#
# Strimzi KafkaConnect는 MSK IAM(custom auth)을 지원하지 않으므로 Debezium 커넥트만
# SCRAM으로 붙는다. 앱/서비스는 계속 IAM(9098) 사용 — MSK는 IAM+SCRAM 공존 지원.
# ⚠️ MSK SCRAM 시크릿 요건: (1) 이름 접두사 'AmazonMSK_', (2) 고객관리 KMS 키로 암호화,
#    (3) kafka.amazonaws.com 이 GetSecretValue 가능한 리소스 정책.
# ---------------------------------------------------------------------------
resource "aws_kms_key" "msk_scram" {
  count                   = var.enable_scram ? 1 : 0
  description             = "CMK for ${var.name} MSK SCRAM secret"
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "aws_kms_alias" "msk_scram" {
  count         = var.enable_scram ? 1 : 0
  name          = "alias/${var.name}-msk-scram"
  target_key_id = aws_kms_key.msk_scram[0].key_id
}

resource "random_password" "scram" {
  count   = var.enable_scram ? 1 : 0
  length  = 24
  special = false # MSK SCRAM 비번은 영숫자 (특수문자로 인한 접속 이슈 회피)
}

resource "aws_secretsmanager_secret" "msk_scram" {
  count      = var.enable_scram ? 1 : 0
  name       = "AmazonMSK_${var.name}_debezium"
  kms_key_id = aws_kms_key.msk_scram[0].arn
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "msk_scram" {
  count     = var.enable_scram ? 1 : 0
  secret_id = aws_secretsmanager_secret.msk_scram[0].id
  secret_string = jsonencode({
    username = var.scram_username
    password = random_password.scram[0].result
  })
}

resource "aws_secretsmanager_secret_policy" "msk_scram" {
  count      = var.enable_scram ? 1 : 0
  secret_arn = aws_secretsmanager_secret.msk_scram[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSKafkaResourcePolicy"
      Effect    = "Allow"
      Principal = { Service = "kafka.amazonaws.com" }
      Action    = "secretsmanager:GetSecretValue"
      Resource  = aws_secretsmanager_secret.msk_scram[0].arn
    }]
  })
}

resource "aws_msk_scram_secret_association" "this" {
  count           = var.enable_scram ? 1 : 0
  cluster_arn     = aws_msk_cluster.this.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_scram[0].arn]

  depends_on = [aws_secretsmanager_secret_version.msk_scram]
}
