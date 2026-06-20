terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # CloudFront ACM + WAF(CLOUDFRONT)는 us-east-1
      configuration_aliases = [aws, aws.us_east_1]
    }
  }
}
