# CI/CD 파이프라인

GitHub Actions로 빌드/테스트 → ECR push(또는 S3) → candle-k8s 태그 bump → ArgoCD 동기화.
인증은 **GitHub OIDC**(키리스), 이미지 태그는 **git SHA**(ECR IMMUTABLE).

## 레포별 워크플로우

| repo | 워크플로우 | 하는 일 |
|---|---|---|
| `micro-services` (Java Spring 멀티모듈) | `.github/workflows/ci.yml` | 변경 모듈만(matrix) test → Jib로 ECR push → candle-k8s 태그 bump |
| `webapp` (TS 모노레포) | `.github/workflows/ci.yml` | bff: 컨테이너→ECR→bump / webapp·admin: 정적 빌드→S3 sync→CloudFront invalidation |
| `candle-k8s` (GitOps) | `.github/workflows/validate.yml` | kustomize build + helm template + kubeconform |
| `infrastructure` (Terraform) | `.github/workflows/terraform.yml` | fmt/validate(전 루트) + plan(dev/prod, read-only role) |

`micro-services`·`webapp`는 공통 composite action `.github/actions/bump-tag` 로 candle-k8s의
`platform/applications/services-<env>.yaml` 에서 해당 서비스 `tag`를 `yq`로 갱신·커밋한다.

## 흐름
```
push main ─▶ build+test ─▶ ECR push (SHA tag)
                              └▶ candle-k8s services-dev.yaml: tag=SHA 커밋
                                          └▶ ArgoCD 자동 sync ─▶ 배포
정적(webapp/admin): build ─▶ S3 sync ─▶ CloudFront invalidation (ArgoCD 미경유)
```
- main 머지 = **dev** 배포. **prod**는 `workflow_dispatch`(env=prod)로 승격(동일 SHA로 prod appset bump).

## 사전 설정 (Terraform 출력 → GitHub)

`terraform -chdir=global apply` 후:
- `ci_deploy_role_arn` → 各 앱 repo **Variable** `CI_DEPLOY_ROLE_ARN`
- `ci_terraform_role_arn` → infrastructure repo **Variable** `CI_TERRAFORM_ROLE_ARN`

### Variables / Secrets

| repo | 종류 | 이름 | 값 |
|---|---|---|---|
| micro-services, webapp | var | `CI_DEPLOY_ROLE_ARN` | `terraform output ci_deploy_role_arn` |
| micro-services, webapp | secret | `GITOPS_TOKEN` | candle-k8s push 권한 PAT(또는 GitHub App) |
| webapp | var | `WEBAPP_DEV_DISTRIBUTION` / `WEBAPP_PROD_DISTRIBUTION` | `terraform output webapp_distribution_id` (env별) |
| webapp | var | `ADMIN_DEV_DISTRIBUTION` / `ADMIN_PROD_DISTRIBUTION` | `terraform output admin_distribution_id` |
| infrastructure | var | `CI_TERRAFORM_ROLE_ARN` | `terraform output ci_terraform_role_arn` |

> S3 버킷명은 결정적(`candle-<env>-<app>`)이라 변수 불필요. CloudFront ID만 변수로.

## 전제 / 조정 포인트
- **micro-services**: 각 서비스가 Gradle 서브프로젝트(`:auth` 등) + **Jib 플러그인** 적용. 모듈 디렉터리명=서비스명(`auth/`…) — 다르면 `ci.yml` paths-filter 수정.
- **Spring Batch (멀티모듈)**: `micro-services` repo의 `*-batch` 모듈(`ranking-batch` 등). CI `batch-build` job이 이미지→ECR push 후 **batch appset**(`bump-tag` `appset: batch`)을 bump. candle-k8s `services/batch-chart`(CronJob)로 배포 — 도메인 DB secret + 도메인 서비스 SA(IRSA) 재사용. JobRepository 메타테이블은 도메인 DB에 생성. CronJob은 `sidecar.istio.io/inject: false`(Job 완료 보장).
- **webapp**: `bff/Dockerfile` 필요. 정적 빌드 산출물은 `<app>/dist`. admin 워크스페이스(`@candle/admin`)가 없으면 matrix에서 제외.
- **OIDC role 신뢰**: `global` 변수 `github_org`/`ci_app_repos`(기본 micro-services, webapp)/`ci_infra_repo`로 sub 제한.
- **apply는 CI 자동화 안 함** — plan만. 적용은 수동/승인(권한 분리).
