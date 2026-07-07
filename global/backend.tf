terraform {
  backend "s3" {
    bucket         = "candle-tfstate-633597729239"
    key            = "global/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "candle-terraform-locks"
    encrypt        = true
  }
}
