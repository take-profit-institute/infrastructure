# 인프라 띄우기 / 내리기 CLI

`candle` 인프라를 올리고(apply) 내리는(destroy) 전체 CLI 절차. 계정 `348062907700`, 리전 `ap-northeast-2`.

> ⚠️ apply는 **실제 과금 리소스**(EKS·MSK·RDS·NAT·Redis)를 만든다. destroy는 **되돌릴 수 없다**.
> 항상 `plan`/`-target`으로 확인 후 실행. 자세한 전제는 [apply-readiness.md](apply-readiness.md).

---

## 0. 사전

```bash
aws sts get-caller-identity         # user/candle-admin (root 아님) 확인
export AWS_REGION=ap-northeast-2
# 프로파일 쓰면: export AWS_PROFILE=candle-admin
cd <repo>/infrastructure
```

---

## 1. 띄우기 (UP)

### 1-1. bootstrap — state 백엔드 (1회, 거의 무료)
```bash
cd bootstrap
terraform init
terraform plan
terraform apply            # S3 state 버킷 + DynamoDB 락
```

### 1-2. global — ECR + GitHub OIDC (저비용)
```bash
cd ../global
terraform init             # S3 backend(위에서 생성됨)
terraform plan
terraform apply
# 출력 확인
terraform output ci_deploy_role_arn
terraform output ci_terraform_role_arn
```
→ 출력값을 GitHub repo Variables/Secrets에 등록 ([ci.md](ci.md)).

### 1-3. dev — 기반 먼저 (2-phase)
```bash
cd ../envs/dev
terraform init
# (1) provider가 의존하는 기반 먼저
terraform plan  -target=module.network -target=module.database -target=module.eks
terraform apply -target=module.network -target=module.database -target=module.eks
#     ↳ EKS 생성 ~15분
```

### 1-4. dev — 나머지 전체
RDS가 private이라 `postgres-init`(postgresql provider)이 도달해야 한다. SSM 터널 또는 VPC 내부 실행.
```bash
# (SSM 터널 예: bastion/노드 통해 RDS:5432 → localhost) 필요 시
terraform plan
terraform apply            # postgres-init / platform(helm) / (edge는 enable_edge=false라 skip)
```
> `enable_edge=false`이면 CloudFront/APIGW/Route53/정적사이트/ws는 안 만들어진다(도메인 확보 후).

### 1-5. GitOps 핸드오프 (candle-k8s)
```bash
aws eks update-kubeconfig --name candle-dev --region ap-northeast-2

# placeholder 치환(<ACCOUNT_ID>/<ECR>/MSK/Debezium) 후 commit
cd <repo>/candle-k8s && scripts/render-placeholders.sh dev
git add -A && git commit -m "render dev" && git push

kubectl apply -f projects/candle.yaml
kubectl apply -f bootstrap/dev.yaml      # 이후 ArgoCD가 전부 sync
```

### 1-6. (도메인 확보 후) edge 켜기
```bash
cd <repo>/infrastructure/envs/dev
# tfvars: 도메인 교체 + enable_edge=true
terraform apply
terraform output route53_name_servers    # NS를 도메인 등록기관에 위임
# candle-k8s NLB 생성 후 그 리스너 ARN을 tfvars edge_mesh_nlb_listener_arn 에 넣고 재apply
```

### prod
`envs/prod`에서 1-3~1-6 반복(클러스터 `candle-prod`, API private라 GitOps는 VPC 내부에서).

---

## 2. 확인 (VERIFY)
```bash
terraform output                                   # 엔드포인트/ARN
kubectl get pods -A
kubectl get applications -n argocd                 # ArgoCD 동기화 상태
kubectl get svc -n istio-ingress                   # 메시 NLB
kubectl get servicemonitor -n candle
```

---

## 3. 내리기 (DOWN) — 역순 + 주의

> ⚠️ **순서 중요.** k8s가 만든 LB/EBS를 먼저 지우지 않으면 VPC destroy가 ENI 의존성으로 **무한 대기**한다.

### 3-1. GitOps 워크로드 먼저 (LB/PVC 정리)
```bash
kubectl delete -f candle-k8s/bootstrap/dev.yaml        # app-of-apps 제거(하위 앱 prune)
# 또는 개별: kubectl delete applicationset -n argocd --all
kubectl delete -f candle-k8s/platform/manifests/base/ws-ingress.yaml 2>/dev/null
# Istio ingress Service(LoadBalancer) 삭제 → ALB/NLB·ENI 제거 확인
kubectl get svc -A | grep LoadBalancer               # 남은 LB 없을 때까지 대기
kubectl delete pvc --all -n candle                   # TimescaleDB 등 EBS 볼륨 회수
```

### 3-2. dev 인프라 destroy
```bash
cd infrastructure/envs/dev
# postgres-init/platform 삭제는 apply와 동일한 연결(클러스터/RDS 도달) 필요.
# 도달 불가하면 state에서 제거 후 진행:
#   terraform state rm 'module.postgres_init' 'module.platform'
terraform destroy
#   ↳ EKS/MSK/RDS 삭제에 수~십분. RDS prod는 deletion_protection 먼저 해제 필요
```

### 3-3. global / bootstrap
```bash
cd ../../global && terraform destroy        # ECR repo는 이미지 있으면 force 필요할 수 있음
cd ../bootstrap
#   state 버킷은 prevent_destroy + 버전닝 → 그냥 destroy 안 됨.
#   완전 삭제하려면: lifecycle prevent_destroy 제거 → 버킷 비우기(버전 포함) → destroy
```

---

## 4. 부분 내리기 / 비용 절감 (전체 destroy 대신)

```bash
# 노드그룹만 0으로 (워크로드 정지, 컨트롤플레인/데이터는 유지)
#   envs/dev/terraform.tfvars: eks_node_min_size=0, desired=0 → terraform apply

# 특정 고비용만 제거 (예: MSK)
terraform destroy -target=module.messaging

# dev만 통째로 내리고 bootstrap/global은 유지 → 위 3-1, 3-2 만 수행
```

---

## 5. 자주 막히는 destroy 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| VPC/subnet destroy 무한 대기 | LB controller가 만든 ALB/NLB·ENI 잔존 | 3-1 먼저(k8s Service/Ingress 삭제) |
| RDS destroy 실패 | `deletion_protection=true`(prod) | tfvars `db_deletion_protection=false` → apply → destroy |
| RDS 최종 스냅샷 요구 | `skip_final_snapshot=false`(prod) | 의도면 스냅샷 생성 허용, 아니면 true로 |
| postgres-init destroy 실패 | RDS(private) 도달 불가 | SSM 터널 OR `terraform state rm module.postgres_init` |
| helm release destroy 실패 | 클러스터 API 도달 불가/이미 삭제 | `terraform state rm module.platform` 후 진행 |
| state 버킷 destroy 안 됨 | `prevent_destroy`+버전 객체 | prevent_destroy 제거 → 버킷 비우기 → destroy |
| Secrets 재생성 시 충돌 | 삭제 복구창(prod 7일) | `aws secretsmanager delete-secret --force-delete-without-recovery` |
| ECR destroy 실패 | repo에 이미지 존재 | 콘솔/`aws ecr batch-delete-image` 후, 또는 force_delete |

> 권장 destroy 순서 요약: **k8s 워크로드(LB/PVC) → dev terraform → global → bootstrap**.
> 비용만 줄이려면 전체 destroy보다 **노드 0 스케일 + MSK/RDS 선택 destroy**가 복구가 쉽다.
