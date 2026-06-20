terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap는 의도적으로 local state를 사용한다.
  # 이 스택이 만드는 S3 버킷/DynamoDB 테이블이 곧 다른 모든 env의 remote backend가 되기 때문.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "candle"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}
