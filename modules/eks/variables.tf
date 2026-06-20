variable "name" {
  description = "EKS 클러스터 이름 (예: candle-dev)"
  type        = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "노드/Pod이 위치할 private 서브넷"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "컨트롤플레인 ENI 서브넷 (보통 private과 동일)"
  type        = list(string)
  default     = []
}

variable "endpoint_public_access" {
  description = "API 서버 퍼블릭 접근 (dev: kubectl 편의 true, prod: 제한 권장)"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# ── 노드그룹 ───────────────────────────────────────────────────────
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
