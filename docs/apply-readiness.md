# Apply 준비 점검 & 배포 런북

`terraform apply` 및 첫 배포 전에 확인/수행해야 할 것. 현재 코드는 검증 통과 상태
(`terraform fmt`/`validate` 4개 루트 OK, candle-k8s kustomize/helm 렌더 OK)이며,
아래 blocker만 처리하면 적용 가능하다.

관련 문서: [ci.md](ci.md) · candle-k8s/docs/{mesh-mtls-grpc,app-implementation-guide}.md · 각 README의 Caveats.

---

## 1. 적용 전 필수 (blocker)

| # | 항목 | 상태 | 조치 |
|---|---|---|---|
| 1 | **AWS 자격증명** | 미설정(`NoCredentials`) | 계정 `348062907700`에 자격증명 설정(아래 1.1). apply 주체는 관리자급 권한 필요(plan용 CI 역할은 ReadOnly) |
| 2 | **State 버킷명 전역 유일** | ✅ `candle-tfstate-348062907700`로 확정 | (완료) S3는 전역 네임스페이스라 계정 ID로 유일화. DynamoDB 락 테이블(`candle-terraform-locks`)은 계정/리전 스코프라 변경 불필요 |
| 3 | **도메인 미확보** | `candle.io` placeholder | **현재 `enable_edge=false`** → CloudFront/APIGW/ACM/Route53/static-site/ws/external-dns **미생성**으로 나머지는 그대로 apply 가능. 도메인 확보 후 tfvars 도메인 교체 + `enable_edge=true` |
| 4 | **(edge 켤 때) NS 위임** | — | `enable_edge=true` apply 후 `terraform output route53_name_servers`의 NS를 등록기관에 등록(안 하면 ACM DNS 검증 무한 대기) |

### 1.1 자격증명 — 무엇이 필요한가

- **시크릿 키는 저(어시스턴트)에게 알려줄 필요 없음.** 로컬/CI에서 직접 설정한다.
- 방법(택1): `aws configure`(액세스 키+시크릿) · `aws configure sso`(SSO) · `aws sts assume-role`.
- **권한**: 첫 apply는 IAM(OIDC provider/role)·VPC·EKS·RDS·MSK·ElastiCache·CloudFront·Route53·S3·Secrets Manager 등을 생성 → 사실상 **AdministratorAccess**(또는 동등 범위) 필요.
- **리전**: `ap-northeast-2`. 단 CloudFront ACM/WAF는 `us-east-1`(provider alias로 자동 처리).
- 확인: `aws sts get-caller-identity` → Account `348062907700` 인지 체크.
- bootstrap은 local state로 S3/DynamoDB를 만들므로 위 자격증명만 있으면 됨.

## 2. 적용 순서 (2-phase 포함)

```bash
# 0) state 인프라 — 1회, local state
cd bootstrap && terraform init && terraform apply

# 1) 공통(ECR + GitHub OIDC roles)
cd ../global && terraform init && terraform apply

# 2) 환경(dev 먼저) — provider가 RDS/EKS 생성에 의존 → 기반 먼저
cd ../envs/dev && terraform init
terraform apply -target=module.network -target=module.database -target=module.eks
terraform apply         # 전체 (postgres-init / platform(helm) / edge / static-site)
```

### 왜 2-phase인가 (provider 의존성)
- **postgres-init**(`postgresql` provider): RDS가 private subnet + `publicly_accessible=false` → 도달 경로 필요. SSM 포트포워딩/bastion 또는 **VPC 내부 CI 러너**에서 전체 apply.
- **platform**(`helm`/`kubernetes` provider): EKS 클러스터가 있어야 동작 → `-target=module.eks` 선행.
- prod는 EKS API가 private → GitOps/helm/kubectl은 **VPC 내부**에서 실행.

### 소요/비용 주의
- EKS, CloudFront 각각 생성 **~15분**.
- 상시 비용: EKS, **MSK**(prod 3 broker), **RDS**(prod Multi-AZ), **NAT**(prod AZ별), **Redis ×3**, NLB/ALB. → **dev부터**, prod는 신중히.
- creds 설정 후 **`terraform plan`으로 먼저 검토**(생성 목록/비용) 후 apply.

## 3. 단계별로 채울 값

### (a) Terraform tfvars — apply 전
- `envs/*/terraform.tfvars`: 도메인(`edge_zone_name`/`edge_aliases`/`admin_domain`/`webapp_domain`/`ws_domain`/`edge_cors_allow_origins`), `admin_allowed_cidrs`(admin 접근제한 권장).
- `global/variables.tf`: `github_org`(=`take-profit-institute`), `ci_app_repos`/`ci_infra_repo` 확인.
- backend/bootstrap: state 버킷명(위 blocker 2).

### (b) global apply 후 → GitHub 설정 (CI)
| repo | 종류 | 이름 | 값(출처) |
|---|---|---|---|
| micro-services, webapp | var | `CI_DEPLOY_ROLE_ARN` | `terraform -chdir=global output ci_deploy_role_arn` |
| micro-services, webapp | secret | `GITOPS_TOKEN` | candle-k8s push PAT/App |
| webapp | var | `{WEBAPP,ADMIN}_{DEV,PROD}_DISTRIBUTION` | `terraform output {webapp,admin}_distribution_id`(env별) |
| infrastructure | var | `CI_TERRAFORM_ROLE_ARN` | `terraform -chdir=global output ci_terraform_role_arn` |

### (c) dev apply 후 → candle-k8s placeholder 치환
현재 리터럴로 박혀 있어 **ArgoCD sync 전에 실제 값으로 치환·commit** 필요.

| placeholder | 개수 | 값/출처 |
|---|---|---|
| `<ACCOUNT_ID>` | 21 | `aws sts get-caller-identity --query Account` |
| `<ECR>` | 7 | `<account>.dkr.ecr.ap-northeast-2.amazonaws.com` |
| `<MSK_IAM_BOOTSTRAP>` | 1 | `terraform output msk_bootstrap_brokers_iam` (kafka-connect.yaml) |
| `<DEBEZIUM_ROLE_ARN>` | 1 | `terraform output irsa_debezium_role_arn` (kafka-connect.yaml) |

> 계정/리전이 결정적이므로 `sed` 스크립트나 kustomize replacement으로 자동화 권장.
> ws ACM은 LB Controller가 host 매칭으로 자동탐색(치환 불필요).

## 4. 인프라 → GitOps 핸드오프

```bash
aws eks update-kubeconfig --name candle-dev --region ap-northeast-2
# (c) placeholder 치환 + commit 후:
kubectl apply -f candle-k8s/projects/candle.yaml
kubectl apply -f candle-k8s/bootstrap/dev.yaml      # 이후 ArgoCD가 전부 동기화
```
이후 자동 흐름: ArgoCD → istio/strimzi/observability/ESO config + 서비스/배치/timescaledb.

### 양방향 핸드셰이크 2건 (배포 후 역주입)
- **Istio ingress 내부 NLB** 생성됨 → 그 리스너 ARN을 Terraform `edge_mesh_nlb_listener_arn`에 주입 후 `apply` → APIGW→메시 라우트 연결.
- **WS ALB**(ws-ingress) 생성됨 → external-dns가 `ws.<domain>` 레코드 자동 생성(zone 위임 완료 전제).
- **Auth 서비스** 배포 후 → `edge_jwt_issuer` 설정 후 `apply` → APIGW JWT authorizer 활성.

## 5. 앱/Strimzi 측 선행 조건 (요약)
- 서비스: `SERVER_PORT/GRPC_SERVER_PORT`, datasource `${host}/${username}/...` 매핑, actuator+gRPC health, outbox 테이블. (candle-k8s/docs/app-implementation-guide.md)
- batch: native sidecar(이미 설정), JobRepository=`candle/<env>/rds/batch`.
- Debezium: kafka-connect.yaml placeholder 치환 + 서비스별 KafkaConnector(이미 6종).
- bff: `bff/Dockerfile`, `/health`·`/metrics`, Redis pub/sub 재연결.

## 6. 롤백/안전장치
- state 버킷 `prevent_destroy`(bootstrap), prod RDS `deletion_protection=true`/`skip_final_snapshot=false`.
- Secrets 복구창: dev=0(즉시), prod=7일.
- `terraform destroy`는 prod에서 deletion_protection/스냅샷 때문에 단계적 — 함부로 금지.

## 7. 적용 전 최종 체크리스트
- [ ] AWS 자격증명 + 충분한 권한
- [ ] state 버킷/락 테이블명 유니크화
- [ ] 도메인 교체 + (zone 생성 후) NS 위임
- [ ] `terraform plan`(dev) 검토
- [ ] bootstrap → global → dev(-target → 전체) 순서
- [ ] global 후 GitHub var/secret 설정
- [ ] dev 후 candle-k8s placeholder 치환·commit
- [ ] kubeconfig + bootstrap/dev.yaml 적용
- [ ] NLB ARN / jwt issuer 역주입
- [ ] dev 안정화 후 prod 반복
