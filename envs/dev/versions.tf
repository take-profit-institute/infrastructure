terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "candle"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront ACM + WAF(CLOUDFRONT)는 us-east-1 전용
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "candle"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# postgres-init용 — RDS 엔드포인트에 도달 가능한 환경에서만 동작한다.
# (SSM 터널 / VPC 내부 실행. 자세한 내용은 README 참고)
provider "postgresql" {
  host            = module.database.address
  port            = module.database.port
  username        = module.database.master_username
  password        = module.database.master_password
  database        = "candle"
  sslmode         = "require"
  superuser       = false
  connect_timeout = 15
}

# Phase 4 platform용 — EKS 클러스터가 존재해야 동작(2-phase apply, README 참고)
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
