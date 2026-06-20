variable "name" {
  description = "리소스 이름 prefix (예: candle-dev)"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "사용할 가용영역 목록"
  type        = list(string)
}

variable "public_subnets" {
  description = "퍼블릭 서브넷 CIDR (ALB/NAT 위치)"
  type        = list(string)
}

variable "private_subnets" {
  description = "프라이빗 서브넷 CIDR (EKS 노드/Pod 위치)"
  type        = list(string)
}

variable "database_subnets" {
  description = "DB 전용 서브넷 CIDR (RDS/ElastiCache/MSK)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "NAT GW를 1개만 둘지 여부 (dev=비용절감 true, prod=AZ별 false)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
