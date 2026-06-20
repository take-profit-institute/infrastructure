# Remote state — bootstrap 스택이 먼저 생성되어 있어야 한다.
# 최초 init 시: terraform init  (필요하면 -reconfigure)
terraform {
  backend "s3" {
    bucket         = "candle-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "candle-terraform-locks"
    encrypt        = true
  }
}
