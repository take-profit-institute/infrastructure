#!/usr/bin/env bash
# End-to-end bootstrap for one Candle AWS environment.
#
# This script intentionally keeps destructive actions out of scope. It creates or
# updates infrastructure, renders GitOps placeholders from Terraform outputs, and
# applies the ArgoCD app-of-apps root.
#
# Usage:
#   scripts/apply-env.sh dev
#   scripts/apply-env.sh prod
#
# Required:
#   AWS credentials for the target account
#   TF_VAR_jwt_hmac_secret=<same secret used by auth/chat>
#
# Domain/edge:
#   ENABLE_EDGE=true DOMAIN=dev.example.com scripts/apply-env.sh dev
#   ENABLE_EDGE=true DOMAIN=example.com scripts/apply-env.sh prod
#
# Optional:
#   REGION=ap-northeast-2
#   K8S_DIR=/path/to/candle-k8s
#   STATE_BUCKET=candle-tfstate-<account-id>
#   SKIP_BOOTSTRAP=true
#   SKIP_GLOBAL=true
#   SKIP_TERRAFORM=true
#   SKIP_K8S=true
#   AUTO_APPROVE=false
set -euo pipefail

ENVIRONMENT="${1:-dev}"
case "$ENVIRONMENT" in
  dev|prod) ;;
  *)
    echo "usage: $0 [dev|prod]" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K8S_DIR="${K8S_DIR:-$ROOT/../candle-k8s}"
REGION="${REGION:-ap-northeast-2}"
ENABLE_EDGE="${ENABLE_EDGE:-false}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"

if [ -z "${TF_VAR_jwt_hmac_secret:-}" ]; then
  echo "TF_VAR_jwt_hmac_secret is required." >&2
  echo "Example: export TF_VAR_jwt_hmac_secret=\$(openssl rand -base64 48)" >&2
  exit 2
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required." >&2
  exit 127
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required." >&2
  exit 127
fi

if [ "${SKIP_K8S:-false}" != "true" ] && ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required unless SKIP_K8S=true." >&2
  exit 127
fi

TF_APPLY_ARGS=()
if [ "$AUTO_APPROVE" = "true" ]; then
  TF_APPLY_ARGS+=("-auto-approve")
fi

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"
export TF_VAR_region="$REGION"
export TF_VAR_environment="$ENVIRONMENT"
export TF_VAR_enable_edge="$ENABLE_EDGE"

if [ "$ENABLE_EDGE" = "true" ]; then
  DOMAIN="${DOMAIN:-}"
  if [ -z "$DOMAIN" ]; then
    echo "DOMAIN is required when ENABLE_EDGE=true." >&2
    echo "Use DOMAIN=dev.example.com for dev or DOMAIN=example.com for prod." >&2
    exit 2
  fi
  export TF_VAR_edge_zone_name="${EDGE_ZONE_NAME:-$DOMAIN}"
  export TF_VAR_edge_aliases="${EDGE_ALIASES:-[\"api.$DOMAIN\"]}"
  export TF_VAR_admin_domain="${ADMIN_DOMAIN:-admin.$DOMAIN}"
  export TF_VAR_webapp_domain="${WEBAPP_DOMAIN:-app.$DOMAIN}"
  export TF_VAR_ws_domain="${WS_DOMAIN:-ws.$DOMAIN}"
  export TF_VAR_edge_cors_allow_origins="${EDGE_CORS_ALLOW_ORIGINS:-[\"https://app.$DOMAIN\",\"https://admin.$DOMAIN\",\"capacitor://localhost\"]}"
fi

echo "== Candle AWS bootstrap =="
echo "env=$ENVIRONMENT region=$REGION edge=$ENABLE_EDGE"
aws sts get-caller-identity >/dev/null
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="${STATE_BUCKET:-candle-tfstate-$ACCOUNT_ID}"
LOCK_TABLE="${LOCK_TABLE:-candle-terraform-locks}"
BACKEND_CONFIG=(
  "-backend-config=bucket=$STATE_BUCKET"
  "-backend-config=region=$REGION"
  "-backend-config=dynamodb_table=$LOCK_TABLE"
)
echo "account=$ACCOUNT_ID"
echo "state_bucket=$STATE_BUCKET lock_table=$LOCK_TABLE"

if [ "${SKIP_TERRAFORM:-false}" != "true" ]; then
  if [ "${SKIP_BOOTSTRAP:-false}" != "true" ]; then
    echo "== terraform bootstrap =="
    terraform -chdir="$ROOT/bootstrap" init
    terraform -chdir="$ROOT/bootstrap" apply "${TF_APPLY_ARGS[@]}" \
      -var="state_bucket_name=$STATE_BUCKET" \
      -var="lock_table_name=$LOCK_TABLE" \
      -var="region=$REGION"
  fi

  if [ "${SKIP_GLOBAL:-false}" != "true" ]; then
    echo "== terraform global =="
    terraform -chdir="$ROOT/global" init -upgrade -reconfigure "${BACKEND_CONFIG[@]}"
    terraform -chdir="$ROOT/global" apply "${TF_APPLY_ARGS[@]}"
  fi

  echo "== terraform $ENVIRONMENT base phase =="
  terraform -chdir="$ROOT/envs/$ENVIRONMENT" init -upgrade -reconfigure "${BACKEND_CONFIG[@]}"
  terraform -chdir="$ROOT/envs/$ENVIRONMENT" apply "${TF_APPLY_ARGS[@]}" \
    -target=module.network \
    -target=module.database \
    -target=module.eks

  echo "== terraform $ENVIRONMENT full phase =="
  terraform -chdir="$ROOT/envs/$ENVIRONMENT" apply "${TF_APPLY_ARGS[@]}"
fi

if [ "${SKIP_K8S:-false}" != "true" ]; then
  echo "== kubeconfig =="
  CLUSTER_NAME="$(terraform -chdir="$ROOT/envs/$ENVIRONMENT" output -raw eks_cluster_name)"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

  echo "== render candle-k8s placeholders =="
  ACCOUNT_ID="$ACCOUNT_ID" REGION="$REGION" TF_DIR="$ROOT/envs/$ENVIRONMENT" \
    "$K8S_DIR/scripts/render-placeholders.sh" "$ENVIRONMENT"

  echo "== apply ArgoCD root =="
  kubectl apply -f "$K8S_DIR/projects/candle.yaml"
  kubectl apply -f "$K8S_DIR/bootstrap/$ENVIRONMENT.yaml"

  echo "== ArgoCD applications =="
  kubectl get applications -n argocd || true
fi

echo "done"
