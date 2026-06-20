# ---------------------------------------------------------------------------
# GitHub Actions OIDC — 키리스 CI 인증 (account 공통이라 global)
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ── 배포 role: ECR push + 정적 사이트 S3/CloudFront ───────────────
data "aws_iam_policy_document" "ci_deploy" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = ["arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/candle/*"]
  }

  statement {
    sid       = "StaticS3List"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::candle-*-admin", "arn:aws:s3:::candle-*-webapp"]
  }

  statement {
    sid       = "StaticS3Objects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::candle-*-admin/*", "arn:aws:s3:::candle-*-webapp/*"]
  }

  statement {
    sid       = "CloudFrontInvalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = ["*"]
  }
}

module "ci_deploy_role" {
  source = "../modules/iam-github-role"

  name              = "candle-ci-deploy"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  subjects          = [for r in var.ci_app_repos : "repo:${var.github_org}/${r}:*"]
  policy_json       = data.aws_iam_policy_document.ci_deploy.json
}

# ── Terraform plan role: 읽기 전용 (apply는 별도 승인/권한 권장) ──
module "ci_terraform_role" {
  source = "../modules/iam-github-role"

  name                = "candle-ci-terraform-plan"
  oidc_provider_arn   = aws_iam_openid_connect_provider.github.arn
  subjects            = ["repo:${var.github_org}/${var.ci_infra_repo}:*"]
  managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
