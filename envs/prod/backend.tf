# Remote state — bootstrap 스택이 먼저 생성되어 있어야 한다.
terraform {
  backend "s3" {
    bucket         = "candle-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "candle-terraform-locks"
    encrypt        = true
  }
}
