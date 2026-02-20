---
name: selfish:security
description: "보안 스캔 (읽기 전용)"
argument-hint: "[스캔 범위: 파일/디렉토리 경로 또는 full]"
disable-model-invocation: true
context: fork
agent: Explore
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
model: sonnet
---

# /selfish:security — 보안 스캔

> 코드베이스의 보안 취약점을 탐지하고 보고한다.
> OWASP Top 10 기준으로 검사한다. **읽기 전용** — 코드를 수정하지 않는다.

## 인자

- `$ARGUMENTS` — (선택) 스캔 범위 (파일/디렉토리 경로, 또는 "full" 전체 스캔)
  - 미지정 시: 현재 브랜치의 변경 파일만 스캔

## 설정 로드

프로젝트 루트의 `CLAUDE.md` 또는 `.claude/CLAUDE.md`에서 다음 설정을 읽어 `config` 변수에 할당:

```
config.framework  = 프로젝트에서 사용하는 프레임워크
                    (예: "Next.js", "Nuxt", "SvelteKit", "Express", "NestJS")
                    → CLAUDE.md에 명시된 프레임워크 기준. 없으면 "알 수 없음"으로 가정.
config.auditCmd   = 의존성 감사 명령어
                    (예: "yarn audit", "npm audit", "pnpm audit")
                    → package.json의 packageManager 필드 또는 lockfile 기준으로 추론.
```

## 실행 절차

### 1. 스캔 범위 결정

- `$ARGUMENTS` = 경로 → 해당 경로만
- `$ARGUMENTS` = "full" → `src/` 전체
- 미지정 → `git diff --name-only HEAD` 변경 파일

### 2. Agent Teams (파일 10개 초과 시)

넓은 범위 스캔 시 병렬 에이전트:
```
Task("Security scan: src/features/", subagent_type: general-purpose)
Task("Security scan: src/shared/api/", subagent_type: general-purpose)
```

### 3. 보안 검사 항목

#### A. Injection (A03:2021)
- `dangerouslySetInnerHTML` 사용처
- 사용자 입력이 직접 DOM/URL/쿼리에 삽입되는 곳
- `eval()`, `new Function()` 사용

#### B. Broken Authentication (A07:2021)
- 토큰/인증 정보 하드코딩
- 인증 없이 접근 가능한 API 라우트
- 세션 관리 취약점

#### C. Sensitive Data Exposure (A02:2021)
- `.env` 값이 클라이언트에 노출 (프레임워크별 클라이언트 노출 변수 (예: {config.framework} 환경의 공개 환경변수) 확인)
- console.log에 민감 정보 출력
- 에러 메시지에 내부 정보 노출

#### D. Security Misconfiguration (A05:2021)
- CORS 설정
- CSP 헤더
- 불필요한 디버그 모드

#### E. XSS (A03:2021)
- React의 기본 이스케이핑을 우회하는 패턴
- URL 파라미터를 검증 없이 렌더링
- iframe/script 동적 삽입

#### F. Dependencies (A06:2021)
- 알려진 취약점 있는 패키지 (의존성 감사 도구 결과)
- 오래된 의존성

### 4. 결과 출력

```markdown
## 보안 스캔 결과

### 요약
| 심각도 | 개수 |
|--------|------|
| 🔴 Critical | {N} |
| 🟠 High | {N} |
| 🟡 Medium | {N} |
| 🔵 Low | {N} |

### 발견사항

#### 🔴 SEC-{NNN}: {제목}
- **카테고리**: {OWASP 코드}
- **파일**: {경로}:{라인}
- **설명**: {취약점 상세}
- **영향**: {악용 시 영향}
- **완화**: {수정 방법}

### 의존성 감사
{{config.auditCmd} 결과 요약 — 실행 가능한 경우}

### 권장 조치
{우선순위 순으로 수정 제안}
```

### 5. 최종 출력

```
🔒 보안 스캔 완료
├─ 범위: {파일 수}개 파일
├─ 발견: 🔴 {N} / 🟠 {N} / 🟡 {N} / 🔵 {N}
└─ 권장: {가장 시급한 조치}
```

## 주의사항

- **읽기 전용**: 코드를 수정하지 않음. 보안 이슈 보고만 수행.
- **오탐 최소화**: React의 기본 XSS 방어를 고려. 실제 위험한 패턴만 보고.
- **민감 정보 주의**: 스캔 결과에 실제 토큰/비밀번호 값을 포함하지 않음.
- **컨텍스트 고려**: {config.framework} 환경에서의 보안 특수성 반영.
