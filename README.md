# Candle Infrastructure (IaC)

Candle(학습형 모의투자 플랫폼)의 AWS 인프라를 Terraform으로 관리합니다.

## 핵심 결정사항

| 항목 | 결정 |
|------|------|
| IaC 도구 | Terraform (`terraform-aws-modules` 커뮤니티 모듈 + 얇은 wrapper) |
| 환경 | `dev`, `prod` (차이는 주로 `terraform.tfvars`로 흡수) |
| 리전 | `ap-northeast-2` (서울) |
| RDS | **단일 PostgreSQL 인스턴스 + 서비스별 DB 분리** (7개 DB) — dev·prod 동일 |
| Market DB | **TimescaleDB** (별도 호스팅 — RDS는 미지원) |
| 시크릿 | **AWS Secrets Manager** (DB 비번 등 TF state에 평문 미저장, IRSA로 주입) |
| State | S3 + DynamoDB 락 (`bootstrap` 스택이 생성) |

## IaC vs GitOps 경계 (중요)

- **Terraform**: AWS 리소스 + 클러스터 부트스트랩(`helm_release`로 ArgoCD·Istio·관측스택 설치)까지.
- **ArgoCD (candle-k8s repo)**: 마이크로서비스 8종 배포, Istio 설정, HPA, 관측 운영.

→ Terraform이 ArgoCD를 깔면, 그 이후 애플리케이션 배포는 GitOps가 담당합니다.

## 디렉토리 구조

```
infrastructure/
├── bootstrap/          # 1회성: state용 S3 + DynamoDB (local state)
├── modules/            # 재사용 모듈 (환경 무관)
│   ├── network/        # ✅ VPC/subnet/NAT
│   ├── database/       # ✅ 단일 RDS + logical replication(CDC) + Secrets Manager
│   ├── postgres-init/  # ✅ 서비스별 DB + role + Debezium replication role
│   ├── timescale/      # ✅ Market TimescaleDB 자격증명(secret). DB본체는 candle-k8s
│   ├── redis/          # ✅ ElastiCache Redis (용도별 1개)
│   ├── messaging/      # ✅ MSK (Kafka, IAM+TLS)
│   ├── ecr/            # ✅ 마이크로서비스 이미지 repo
│   ├── eks/            # ✅ EKS 클러스터 + 노드그룹 + EBS CSI + OIDC
│   ├── irsa-service/   # ✅ ServiceAccount↔IAM (secret/MSK/SES)
│   ├── platform/       # ✅ helm 부트스트랩 (LB Controller/ESO/ArgoCD) + IRSA
│   ├── edge/           # ✅ CloudFront+WAF / API Gateway(+CORS) / Route53 / ACM
│   └── static-site/    # ✅ 정적 SPA (S3+OAC+CloudFront+ACM+WAF) — admin/webapp
├── envs/
│   ├── dev/            # ✅ ~edge 까지
│   └── prod/           # ✅ ~edge 까지
├── global/             # ✅ 환경 공통 ECR (build once → dev/prod promote)
└── global/             # (예정) Route53, ACM 등 환경 공통
```

## 사용법

### 0. Bootstrap (최초 1회)
```bash
cd bootstrap
terraform init
terraform apply
```

### 1. 환경 배포
```bash
cd envs/dev   # 또는 envs/prod
terraform init
terraform plan
terraform apply
```

> 사전 요구: Terraform >= 1.6, AWS 자격증명(CLI profile 또는 env). `terraform` 미설치 시 `tfenv` 또는 `brew install terraform`.

## 구축 로드맵 (레이어 순서)

- [x] **Phase 0** — Bootstrap (state)
- [x] **Phase 1** — Network (VPC)
- [x] **Phase 2** — Data & Messaging
  - [x] 단일 RDS + 서비스별 DB 7개 + Secrets Manager + CDC용 logical replication
  - [x] ElastiCache Redis ×2 (시세캐시 TTL / Ranking Sorted Set)
  - [x] Market TimescaleDB 자격증명 (DB 본체는 EKS StatefulSet → candle-k8s)
  - [x] MSK (Kafka, IAM+TLS) — Debezium CDC outbox
  - [x] ECR (global)
- [x] **Phase 3** — EKS 클러스터 + 노드그룹 + EBS CSI + 서비스별 IRSA
- [~] **Phase 4** — Platform bootstrap
  - [x] Terraform: AWS LB Controller, External Secrets Operator, ArgoCD (+ IRSA)
  - [ ] ArgoCD(candle-k8s): Istio, Strimzi(Debezium), 관측 스택, 마이크로서비스
  - [ ] external-dns (Route53 zone 준비됨 → platform `enable_external_dns=true`로 활성화 가능)
- [x] **Phase 5** — Edge: CloudFront+WAF → API Gateway(JWT·RateLimit) → VPC Link → 메시 NLB, ACM(us-east-1), Route53 zone

각 Phase는 `modules/<name>` 작성 → `envs/{dev,prod}/main.tf`에서 호출 → `plan/apply` 순으로 진행합니다.

## 서비스 ↔ DB 매핑 (단일 RDS 인스턴스)

| 마이크로서비스 | DB | 비고 |
|---|---|---|
| Auth | `auth` | |
| User | `users` | `user`는 SQL 예약어 |
| Account+Trading | `trading` | 통합 서비스 |
| Portfolio | `portfolio` | 보유종목 |
| Ranking | `ranking` | 영속화 (실시간은 Redis Sorted Set) |
| Mission | `mission` | |
| Learning | `learning` | |
| Market | TimescaleDB | EKS StatefulSet (candle-k8s) — Terraform은 secret만 |

## RDS DB 생성 시 2-phase apply (postgres-init)

`postgres-init`의 `postgresql` provider는 RDS 엔드포인트에 직접 연결해야 한다. RDS는 private subnet + `publicly_accessible=false`이므로:

```bash
# 1) 인스턴스/시크릿 먼저 생성
terraform apply -target=module.database

# 2) SSM 포트포워딩(또는 VPC 내부 러너)으로 RDS 터널을 연 뒤 전체 apply
#    예: aws ssm start-session ... 로 localhost:5432 → RDS:5432
terraform apply
```

CI를 VPC 내부(예: EKS self-hosted runner)에서 돌리면 터널 없이 한 번에 apply 가능하다.

## CDC / Debezium (Transactional Outbox)

서비스는 Kafka에 직접 발행하지 않고 **outbox 테이블**에 기록 → **Debezium**이 RDS의 WAL을 logical decoding으로 읽어 MSK로 발행한다.

Terraform이 준비하는 것:
- **RDS logical replication** — `rds.logical_replication=1` 파라미터 그룹 (`database` 모듈)
- **Debezium replication role** — `rds_replication` 권한 + 각 DB CONNECT (`postgres-init`), 자격증명은 `candle/<env>/rds/debezium` secret
- **MSK** — IAM 인증, 토픽 자동생성 활성(신규 이벤트 유연 대응)

Terraform 영역이 아닌 것:
- 각 서비스 DB의 `outbox` 테이블 + publication/테이블 SELECT 권한 → **앱 마이그레이션**
- Debezium 커넥터(Kafka Connect) 실행 → **Strimzi KafkaConnect on EKS** (candle-k8s/GitOps, Phase 4). Terraform은 Connect 파드용 IRSA(① MSK IAM 인증 ② debezium secret 읽기)만 Phase 3/4에서 제공
- 토픽 구독(Ranking/Mission/Notification 소비) → 각 서비스 코드

> 이벤트 흐름 예: `TradeExecuted`, `UserUpdated`, `MissionAchieved` — outbox → Debezium → MSK 토픽 → 구독 서비스.

## EKS / IRSA 규약

- 클러스터: v20 모듈, **access entries** 방식(aws-auth configMap 미사용). dev는 API 퍼블릭, **prod는 프라이빗**(GitOps/CI는 VPC 내부에서 접근).
- **EBS CSI** 드라이버를 IRSA와 함께 활성화 → TimescaleDB 등 StatefulSet PVC용. (gp3 StorageClass 매니페스트는 candle-k8s)
- **IRSA role ↔ ServiceAccount** 매핑 (candle-k8s가 SA 애너테이션 `eks.amazonaws.com/role-arn`에 아래 ARN 사용):

| 서비스 | Namespace/SA | 권한 |
|---|---|---|
| auth·user·trading·portfolio·ranking·mission·learning | `candle/<svc>` | 본인 DB secret + MSK IAM |
| market | `candle/market` | Timescale secret + MSK IAM |
| notification | `candle/notification` | SES 발송 + MSK IAM |
| debezium | `kafka/debezium-connect` | debezium secret + MSK IAM |

> SA 이름은 DB명과 다를 수 있음: `users` DB ↔ `user` 서비스. role ARN은 `terraform output irsa_app_role_arns`로 확인.

> kubectl 접근: `aws eks update-kubeconfig --name <cluster> --region ap-northeast-2`

## Terraform ↔ ArgoCD 경계 (Phase 4)

```
Terraform (modules/platform)            ArgoCD (candle-k8s repo)
├─ AWS Load Balancer Controller         ├─ Istio (base/istiod/gateway)
├─ External Secrets Operator            ├─ Strimzi + Debezium 커넥터
├─ (선택) external-dns                   ├─ 관측 스택 (Prometheus/Grafana/Loki/Jaeger)
└─ ArgoCD  ──── 핸드오프 ───▶           ├─ TimescaleDB StatefulSet (+ gp3 StorageClass)
                                        └─ 마이크로서비스 8종 + HPA
```

- Terraform은 **IRSA가 필요하거나 GitOps가 의존하는 부트스트랩 계층**까지만 helm으로 설치.
- ArgoCD 설치 직후부터는 candle-k8s의 매니페스트(app-of-apps)가 나머지를 동기화.
- ESO가 `candle/<env>/...` secret을 k8s Secret으로 동기화 → 각 서비스/TimescaleDB가 사용.

## Edge (Phase 5)

```
Client → CloudFront(WAF, ACM) → API Gateway(HTTP API: JWT·RateLimit)
       → VPC Link → Istio ingress NLB(candle-k8s) → mesh
```

- **ALB/NLB는 Terraform이 만들지 않음** — AWS LB Controller가 Istio ingress(k8s Service/Gateway)에서 생성. Terraform은 그 **내부 NLB 리스너 ARN을 변수로 받아** APIGW 라우트를 연결.
- CloudFront origin = APIGW 기본 `execute-api` 엔드포인트(커스텀 도메인 불필요). ACM은 **us-east-1 1장**(CloudFront/WAF가 us-east-1 전용).
- **Route53 zone은 Terraform이 신규 생성** → `terraform output route53_name_servers`의 NS를 도메인 등록기관에 등록해야 도메인이 활성화됨.

배포 후 채워야 할 2개 변수(처음엔 비어 있어 APIGW 라우트/JWT 비활성):
| 변수 | 언제 | 효과 |
|---|---|---|
| `edge_jwt_issuer` (+`edge_jwt_audience`) | Auth 서비스 배포 후 | JWT authorizer 활성화 (`/auth/*`는 public 유지) |
| `edge_mesh_nlb_listener_arn` | candle-k8s가 Istio ingress 내부 NLB 생성 후 | APIGW → 메시 라우트 연결 |

> 메시 NLB SG는 `terraform output edge_vpc_link_security_group_id`로부터의 인바운드를 허용해야 함.

## 적용(Apply) 순서 요약

```bash
# 0) state 인프라 (1회, local state)
cd bootstrap && terraform apply

# 1) 공통 ECR
cd ../global && terraform init && terraform apply

# 2) 환경 — 2-phase (provider가 RDS/EKS 생성에 의존)
cd ../envs/dev
terraform init
terraform apply -target=module.network -target=module.database -target=module.eks  # 기반 먼저
#   ↳ 이후 SSM 터널/ VPC 내부에서 postgres-init·platform 도달 가능해진 뒤
terraform apply                                                                     # 전체
```

## ⚠️ 운영 주의사항 (Caveats)

1. **AWS 자격증명 필요** — 현재까지 `validate`만 수행, `apply` 미실행. CLI profile/env 설정 후 위 순서로.
2. **2-phase apply (postgres-init)** — `postgresql` provider가 RDS(private)에 도달해야 함. `-target=module.database` 먼저 → SSM 포트포워딩/VPC 내부 러너로 터널 → 전체 apply. CI를 VPC 내부에서 돌리면 한 번에 가능.
3. **2-phase apply (platform)** — `helm`/`kubernetes` provider가 EKS 생성에 의존. `-target=module.eks` 먼저 apply 후 전체 apply.
4. **prod EKS API 프라이빗** — `endpoint_public_access=false`. Phase 4 helm/ArgoCD·kubectl은 **VPC 내부(CI 러너/bastion)**에서 실행해야 함. (dev는 퍼블릭)
5. **EKS 생성 ~15분** — 클러스터+노드그룹 프로비저닝에 시간 소요.
6. **MSK 브로커 수 = 서브넷 수** — `number_of_broker_nodes`는 AZ(서브넷) 개수의 배수. dev=2, prod=3로 설정됨.
7. **RDS는 TimescaleDB 미지원** — Market은 EKS StatefulSet(candle-k8s). Terraform은 secret만.
8. **ServiceAccount 이름 ≠ DB 이름** — `users` DB ↔ `user` 서비스. `eks.tf`의 `local.service_accounts` 매핑 확인.
9. **state 버킷 보호** — `bootstrap`의 S3 버킷은 `prevent_destroy`. bootstrap 자체는 local state(체크인 금지는 .gitignore가 처리).
10. **Secrets 복구 기간** — dev=0(즉시 삭제 → 재생성 편의), prod=7일. 운영 secret 실수 삭제 주의.
11. **ECR는 공유(global state)** — build once → dev/prod 동일 이미지 promote. repo는 `candle/<svc>`.
12. **증권사 API 화이트리스트** — 아웃바운드 고정 IP는 `terraform output nat_public_ips`(NAT EIP). 증권사에 등록.
13. **ArgoCD server insecure** — ALB에서 TLS 종료 전제(`configs.params.server.insecure=true`). Edge(Phase 5) 구성 시 ALB/ACM과 함께 점검.
14. **logical replication는 재부팅 필요** — `rds.logical_replication` 파라미터는 `pending-reboot`. 최초 apply 후 RDS 재부팅 시점에 적용됨.
15. **Edge 도메인 NS 위임** — Route53 zone 생성 후 `route53_name_servers` NS를 도메인 등록기관에 등록해야 ACM DNS 검증·도메인이 동작. 미등록 시 `aws_acm_certificate_validation`이 검증 대기로 멈춤.
16. **Edge 2개 변수 후속 주입** — `edge_jwt_issuer`(Auth 배포 후), `edge_mesh_nlb_listener_arn`(candle-k8s NLB 후). 비어 있으면 APIGW 라우트/JWT 미적용 상태로 생성됨.
17. **us-east-1 provider** — CloudFront ACM·WAF는 us-east-1 alias로 생성. env에 `aws.us_east_1` provider 구성 필요(이미 배선됨).
18. **CloudFront 배포 ~15분** — 생성/변경 전파에 시간 소요.
19. **도메인 레이아웃** — API=`api.<zone>`(edge), webapp=`app.<zone>`·admin=`admin.<zone>`(static-site). 같은 zone 공유. admin은 `admin_allowed_cidrs`로 IP 제한 권장.
20. **정적 사이트 배포** — CI가 `terraform output {admin,webapp}_bucket` 에 업로드 후 `{...}_distribution_id` invalidation. 딥링크 파일(`/.well-known/apple-app-site-association`, `assetlinks.json`)도 올바른 content-type으로 함께 업로드.
21. **APIGW CORS** — 앱 래핑(Capacitor/WebView) origin은 `edge_cors_allow_origins`로 명시(allow_credentials=true라 `*` 불가).
22. **WebSocket은 API Gateway로 안 감** — HTTP API는 WS 미지원. Market 실시간(Redis Pub/Sub→BFF sub→WS)은 **전용 `ws.<domain>` → 인터넷 ALB**(candle-k8s Ingress)로 처리. Terraform은 regional ACM(`ws_acm_certificate_arn`)만 발급, ALB/레코드는 candle-k8s + external-dns. ALB idle timeout 상향 + WS heartbeat 필요.
23. **Pub/Sub은 전용 Redis** — `redis_market_pubsub`(캐시와 분리, noeviction, 백업X). BFF 각 레플리카가 sub하므로 sticky session 불필요, failover 시 재연결은 앱 책임.
24. **external-dns 활성화됨** — WS ALB의 `ws.<domain>` 레코드 자동 생성. Terraform이 관리하는 api/app/admin 레코드와 이름이 달라 충돌 없음(TXT 소유권).
