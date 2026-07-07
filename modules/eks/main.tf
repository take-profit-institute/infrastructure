# ---------------------------------------------------------------------------
# EKS 모듈 — terraform-aws-modules/eks wrapper (v20, access entries 방식)
# 클러스터 + 매니지드 노드그룹 + 핵심 애드온 + OIDC(IRSA).
# EBS CSI는 TimescaleDB 등 StatefulSet PVC를 위해 IRSA와 함께 활성화.
# ---------------------------------------------------------------------------

locals {
  control_plane_subnets = length(var.control_plane_subnet_ids) > 0 ? var.control_plane_subnet_ids : var.subnet_ids
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access       = var.endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.public_access_cidrs

  # 클러스터 생성자(테라폼 실행 주체)에게 admin 접근 부여
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = local.control_plane_subnets

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # EKS 컨트롤플레인(API 서버) → 노드의 admission webhook 포트 허용.
  # istio sidecar injector(15017)·istiod xDS(15012)가 없으면 Pod 생성 시 웹훅 timeout으로
  # 모든 서비스 Pod가 FailedCreate 된다(EKS 기본 노드 SG는 이 포트를 안 열어줌).
  node_security_group_additional_rules = {
    istio_sidecar_injector_webhook = {
      description                   = "Control plane to istio sidecar injector webhook"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    istiod_xds = {
      description                   = "Control plane to istiod xDS/webhook"
      protocol                      = "tcp"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    capacity_type = var.node_capacity_type
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }

  tags = var.tags
}

# ── EBS CSI 드라이버 (IRSA) ────────────────────────────────────────
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${var.name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
}
