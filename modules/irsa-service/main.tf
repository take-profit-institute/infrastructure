# ---------------------------------------------------------------------------
# irsa-service — k8s ServiceAccount ↔ IAM role (IRSA)
# 서비스가 본인 secret(Secrets Manager) 읽기 + 필요 시 MSK IAM / SES 등 부여.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# ── Secrets Manager 읽기 ───────────────────────────────────────────
data "aws_iam_policy_document" "secrets" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = var.secret_arns
  }
}

resource "aws_iam_role_policy" "secrets" {
  count  = length(var.secret_arns) > 0 ? 1 : 0
  name   = "secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.secrets[0].json
}

# ── MSK IAM (선택) ─────────────────────────────────────────────────
locals {
  msk_topic_arn = var.msk_cluster_arn != "" ? replace(var.msk_cluster_arn, ":cluster/", ":topic/") : ""
  msk_group_arn = var.msk_cluster_arn != "" ? replace(var.msk_cluster_arn, ":cluster/", ":group/") : ""
}

data "aws_iam_policy_document" "msk" {
  count = var.msk_cluster_arn != "" ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"]
    resources = [var.msk_cluster_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:*Topic*",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData",
    ]
    resources = ["${local.msk_topic_arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup",
    ]
    resources = ["${local.msk_group_arn}/*"]
  }
}

resource "aws_iam_role_policy" "msk" {
  count  = var.msk_cluster_arn != "" ? 1 : 0
  name   = "msk"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.msk[0].json
}

# ── 추가 정책 (선택) ───────────────────────────────────────────────
resource "aws_iam_role_policy" "additional" {
  count  = var.additional_policy_json != "" ? 1 : 0
  name   = "additional"
  role   = aws_iam_role.this.id
  policy = var.additional_policy_json
}
