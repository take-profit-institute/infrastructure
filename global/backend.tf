terraform {
  backend "s3" {
    bucket         = "candle-tfstate-348062907700"
    key            = "global/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "candle-terraform-locks"
    encrypt        = true
  }
}
