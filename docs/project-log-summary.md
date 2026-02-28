# Serverless OpenClaw — 프로젝트 진행 로그 요약

Claude Code 세션 로그(28개 세션, 2026.02.08~02.28)를 분석하여 프로젝트 진행 과정을 요약.

---

## Phase 0: 설계 (2/8, 1일)

### 세션 1 — PRD 작성 & 아키텍처 설계
- **시작**: "이 프로젝트는 MoltWorker를 참고해서 OpenClaw를 서버리스 환경에서 동작시키는 프로젝트. PRD 작성을 위해 심층 인터뷰를 진행해줘"
- AI가 `AskUserQuestionTool`로 인터뷰 진행 → 요구사항 도출
- **비용 최적화 조사**: "ECS Fargate도 스팟 구성으로 하고 ELB 대신 API GW를 사용하면 월 비용이 얼마나 나올까? 퍼플렉시티를 활용해서 조사해줘"
- **컨테이너 Lambda 검토**: "ECS Fargate 대신 컨테이너 기반 람다를 사용한다면 어떨까?" → 15분 제한으로 부적합 결론
- **산출물**: `docs/PRD.md`, `docs/architecture.md`, `docs/implementation-plan.md`, `docs/cost-optimization.md`, `README.md`
- **핵심 결정**: NAT Gateway 제거($33/월 절감), ALB→API Gateway($18~25/월 절감), Fargate Spot(70% 할인)

### 세션 2 — Skills 설정 & 구현 준비
- Skills 레퍼런스 파일을 `docs/` 하위로 이동
- 10단계 구현 계획 확정 (각 단계별 목표/산출물/검증 기준)

---

## Phase 1: MVP 구현 (2/9~2/11, 주로 2/9 하루)

### 2/9 — Step 1-1: 프로젝트 초기화
- npm workspaces 모노레포, TypeScript strict, CDK 스켈레톤
- 공유 패키지(`@serverless-openclaw/shared`) — 타입, 상수, 테이블 이름
- **문제 해결**: 패키지 이름 수정, 빌드 설정 조정

### 2/9 — Step 1-2: 인프라 기반
- NetworkStack (VPC, Public Subnet, natGateways: 0)
- StorageStack (DynamoDB 5개 테이블 PAY_PER_REQUEST)
- CLAUDE.md 작성 (`/init` 명령)
- **개발 규칙 설정**: "구현은 UI를 제외하고는 TDD로 구현. pre-commit에서 UT+lint, pre-push에서 E2E"

### 2/9~10 — Step 1-3: OpenClaw 컨테이너
- Bridge 서버 (:8080 HTTP), OpenClaw Gateway 클라이언트 (:18789 WS)
- JSON-RPC 2.0 프로토콜 구현 (challenge-response 핸드셰이크)
- **테스트 실패 해결**: "테스트 실패를 모두 해결해줘" → vitest mock 이슈 등 수정

### 2/10 — Step 1-4: Gateway Lambda
- 7개 핸들러 (ws-connect, ws-disconnect, ws-message, telegram-webhook, api-handler, watchdog, prewarm)
- 5개 서비스 (task-state, connections, conversations, container, message)
- DI 패턴: `send` 함수 주입

### 2/10~11 — Steps 1-5, 1-6, 1-7: CDK 스택 3개
- AuthStack (Cognito User Pool)
- ComputeStack (ECS Fargate Task Definition, Security Group)
- ApiStack (API Gateway WebSocket + HTTP API)
- **한 번에 3개 스택을 플랜하고 구현** — 의존 관계를 고려한 배치 구현

### 2/11 — Step 1-8: Web Chat UI
- React SPA (Vite), amazon-cognito-identity-js SRP 인증
- WebSocket `?token={idToken}` 쿼리 인증
- WebStack (S3 + CloudFront OAC)
- "지금까지 진행된 내용 설명해줘. 내가 실제 사용해 볼 수 있는건 언제부터야?"

### 2/11 — Step 1-9: Telegram Bot
- 웹훅 기반 (long polling 불가 — API가 동시 사용 거부)
- secret_token 검증, 응답 라우팅 (CallbackSender)
- **컨텍스트 소진**: 세션이 context 한도에 도달 → 새 세션으로 이어서 작업

---

## Phase 1 마무리 (2/13~2/14)

### 2/13 — 프로젝트 정비
- README에 알파 경고 문구 추가
- 기여 가이드 작성 (OpenClaw 참고)
- GitHub 뱃지 추가
- **Git Hook 문제**: pre-commit이 .md 파일에도 빌드를 실행 → docs-only 변경 감지 로직 추가
- "린트 에러도 같이 고쳐줘", "문서 커밋시에는 hook 체크 우회하도록 설정해줘"

### 2/14 — Step 1-10: 통합 테스트 & 문서화 + 실제 AWS 배포
- 배포 가이드, 개발 가이드, E2E 테스트 스캐폴드
- **실제 AWS 배포 진행** — 여러 배포 이슈 해결
  - SecretsStack: `AWS::SSM::Parameter`가 SecureString 미지원 → `AwsCustomResource` 사용
  - Cross-stack 순환 참조 → SSM Parameter Store 기반 디커플링
  - Lambda env에서 `{{resolve:ssm-secure:...}}` 미지원 → 런타임 `resolveSecrets()` 패턴
- **영문 번역**: "이제 모든 문서들을 영문으로 번역해줘" (README, CLAUDE.md, docs/ 전체)
- **134개+ 메시지** — 가장 긴 세션 (39MB 로그), 배포 트러블슈팅 집중

### 2/14 — CloudWatch 모니터링
- 커스텀 메트릭 10개 (startup phases, message latency, response length, prewarm)
- 모니터링 대시보드 6 섹션
- "대시보드 개선해줘. 그루핑과 설명 추가등을 통해 가독성을 개선해줘"

### 2/14 — Telegram-Web Identity Linking
- OTP 기반 연동: 웹에서 6자리 OTP 생성 → Telegram `/link {code}` → 양방향 링크
- 컨테이너 공유: 연동된 사용자는 동일 userId로 Web/Telegram 사용
- REST API: POST /link/generate-otp, GET /link/status, POST /link/unlink

---

## Phase 2: 최적화 (2/15~2/19)

### 2/15 — 콜드 스타트 최적화 & 컨테이너 공유
- Dynamic Inactivity Timeout (Issue #5)
- "현재는 텔레그램, 웹 접근마다 각각 하나씩 띄우는 구조 같아. 사용자당 1개의 컨테이너를 공유해서 쓰게 해줘"
- Telegram-Web 연동 UX 개선: 실시간 카운터, 타임오버 시 새 코드 생성 버튼
- Message Latency 메트릭 수집 문제 해결
- Secrets Manager → SSM Parameter Store 마이그레이션 (월 $0.40×5 = $2 절감)

### 2/15 — 콜드 스타트 집중 최적화
- Docker 이미지: 2.22GB → 1.27GB (43% 감소)
  - AWS CLI 제거 (-358MB) → `@aws-sdk/client-s3` Node.js 대체
  - chown 레이어 최적화 (-134MB)
- CPU 업그레이드 (0.25→1 vCPU): 120s → 68s
- 컨테이너 시작 병렬화: Promise.all
- SOCI Lazy Loading, zstd 압축
- OpenClaw 버전 피닝 (v2026.2.13 — v2026.2.14는 scope 에러로 broken)

### 2/19 — P9: 예측적 프리워밍
- EventBridge cron → prewarm Lambda → ECS RunTask (system:prewarm)
- 컨테이너 클레이밍: 첫 실제 사용자가 prewarm 컨테이너를 인수
- **콜드 스타트 0초 달성** (프리워밍 활성 시)
- "PR #10에 대해, 이 프로젝트가 원래 MoltWorker를 AWS에 이식하려는 시도에서 출발한 것임을 상기시키고 클로즈 해줘"

---

## Phase 3: 배포 안정화 (2/24)

### 2/24 — SecretsStack CDK 배포 & 트러블슈팅
- CDK-managed SSM SecureString 파라미터
- **61개+ 메시지** — 대량의 배포 이슈 해결
  - "배포 진행하고 문제 없는거 확인해"
  - "파라미터 이름 고쳐서 다시 배포해"
  - "에러 원인 확인해서 고쳐"
  - "force delete 해" (ROLLBACK_FAILED 스택)
  - "ssm-secure reference 에러 원인 파악하고 해결해"
- CfnParameter 이름 규칙, empty env vars 문제, ROLLBACK_FAILED cleanup 등 다수 교훈

---

## Phase 4: 문서화 & 발표 준비 (2/28)

### 2/28 — OpenClaw 아키텍처 분석
- "향후 람다 도입등을 통해 최대한 서버리스화를 진행하고 싶어. OpenClaw를 분석해서 아키텍처와 동작 시퀀스를 문서화 해줘"
- 6개 병렬 Explore 에이전트로 675K 줄 코드 분석
- `docs/openclaw-analysis.md` (1075줄) 작성

### 2/28 — 발표 슬라이드 제작
- "바이브 코딩으로 완성하는 AWS 서버리스 OpenClaw" 슬라이드 제작
- MARP → PPTX 변환

---

## 주요 수치

| 지표 | 값 |
|------|-----|
| 총 세션 수 | 28개 |
| 가장 긴 세션 | 39MB (2/14 배포+번역+최적화, 134+ 메시지) |
| 총 로그 크기 | ~98MB |
| 컨텍스트 소진 횟수 | 4회 (자동 이어서 진행) |
| Phase 0 (설계) | 1일 |
| Phase 1 (MVP) | 주로 2/9 하루 (마무리 2/11까지) |
| Phase 2 (최적화) | 2/12~2/19 |
| Phase 3 (안정화) | 2/24 |

## Idea → Implementation → Learning 사이클 사례

### 사이클 1: 비용 최적화
- **Idea**: "비용 최적화를 극한까지 하고 싶어"
- **Implementation**: NAT GW 제거, ALB→API GW, Fargate Spot
- **Learning**: 비용 $0.27~$1.11/월 달성. 단, Secrets Manager 비용($2/월) 발견 → SSM 마이그레이션

### 사이클 2: 콜드 스타트 해결
- **Idea**: "첫 응답까지 126초나 걸린다"
- **Implementation**: 9단계 최적화 (Docker 최적화, CPU 업그레이드, 병렬화, zstd, 프리워밍)
- **Learning**: 각 단계마다 측정→분석→구현→검증 반복. v2026.2.14 호환성 깨짐 발견 → 버전 피닝

### 사이클 3: 컨테이너 공유
- **Idea**: "텔레그램, 웹 접근마다 각각 하나씩 띄우는 구조. 사용자당 1개로"
- **Implementation**: OTP 기반 Telegram-Web Identity Linking
- **Learning**: IDOR 방지를 위해 unlink는 Web-only로 제한

### 사이클 4: CDK 배포 안정화
- **Idea**: "cdk deploy --all로 전체 배포"
- **Implementation**: SecretsStack, cross-stack SSM 디커플링, deploy skill
- **Learning**: 61+ 메시지에 걸친 트러블슈팅. AwsCustomResource, 런타임 secret resolution 패턴 학습

## CI/CD 파이프라인의 다계층 검증

프로젝트 전반에 걸쳐 다음과 같은 다계층 검증이 속도와 안정성의 핵심이었음:

```
개발자 코드 작성 (AI 생성)
    │
    ├─ 1. TDD: 테스트 먼저 작성 → 구현 → 테스트 통과 확인
    │
    ├─ 2. pre-commit Hook
    │     ├─ TypeScript build (타입 검증)
    │     ├─ ESLint (코드 스타일)
    │     └─ vitest (198개 단위 테스트)
    │
    ├─ 3. pre-push Hook
    │     └─ E2E 테스트 (28개 CDK synth 검증)
    │
    ├─ 4. CLAUDE.md 제약 조건
    │     ├─ "NAT Gateway 금지"
    │     ├─ "DynamoDB PAY_PER_REQUEST만"
    │     └─ "시크릿 디스크 미저장"
    │
    ├─ 5. Skills 체크리스트
    │     ├─ /cost: 비용 제약 자동 주입
    │     └─ /security: 보안 체크리스트
    │
    └─ 6. GitHub Actions CI
          ├─ OIDC 인증 AWS 배포
          ├─ SOCI 인덱스 생성
          └─ 전체 테스트 스위트
```

이 다계층 구조 덕분에:
- AI가 NAT Gateway를 포함하려 할 때 `/cost` 스킬이 차단
- 타입 에러, 린트 에러가 커밋 전에 자동 차단
- CDK synth 검증으로 인프라 변경의 정합성 확인
- **AI가 빠르게 코드를 생성하되, 각 계층에서 자동으로 품질이 검증됨**
