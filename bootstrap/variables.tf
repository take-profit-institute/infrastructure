variable "region" {
  description = "AWS 리전 (서울)"
  type        = string
  default     = "ap-northeast-2"
}

variable "state_bucket_name" {
  description = "Terraform remote state를 저장할 S3 버킷 이름 (전역 유일해야 함)"
  type        = string
  default     = "candle-tfstate-348062907700"
}

variable "lock_table_name" {
  description = "Terraform state 락용 DynamoDB 테이블 이름"
  type        = string
  default     = "candle-terraform-locks"
}
