terraform {
  backend "s3" {
    bucket         = "candle-terraform-state"
    key            = "global/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "candle-terraform-locks"
    encrypt        = true
  }
}
