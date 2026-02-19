# /selfish:review — 코드 리뷰

> 변경된 코드를 종합적으로 리뷰한다 (품질, 보안, 성능, 아키텍처 준수).
> Critic Loop 1회로 리뷰 자체의 완전성을 검증한다.

## 인자

- `$ARGUMENTS` — (선택) 리뷰 범위 지정 (파일 경로, PR 번호, 또는 "staged")
  - 미지정 시: 현재 브랜치의 `git diff` (unstaged + staged) 전체

## 설정 로드

**반드시** `.claude/selfish.config.md`를 먼저 읽는다. 설정 파일이 없으면 중단.

## 실행 절차

### 1. 리뷰 대상 수집

1. **범위 결정**:
   - `$ARGUMENTS` = 파일 경로 → 해당 파일만
   - `$ARGUMENTS` = PR 번호 → `gh pr diff {번호}` 실행
   - `$ARGUMENTS` = "staged" → `git diff --cached`
   - 미지정 → `git diff HEAD` (커밋되지 않은 모든 변경)
2. **변경 파일 목록** 추출
3. 각 변경 파일의 **전체 내용** 읽기 (diff만이 아닌 전체 컨텍스트)

### 2. Agent Teams (파일 5개 초과 시)

변경 파일이 5개 초과면 병렬 리뷰 에이전트 분배:

```
Task("Review: {file1, file2}", subagent_type: general-purpose)
Task("Review: {file3, file4}", subagent_type: general-purpose)
→ 결과 수집 → 통합 리뷰 작성
```

### 3. 리뷰 수행

각 변경 파일에 대해 아래 관점으로 검토:

#### A. 코드 품질
- {config.code_style} 준수 (any 사용, 타입 누락)
- 네이밍 컨벤션 (handleX, isX, UPPER_SNAKE)
- 중복 코드
- 불필요한 복잡성

#### B. {config.architecture}
- 계층 의존성 방향 위반 (하위→상위 import)
- 세그먼트 규칙 (api/, model/, ui/, lib/)
- 적절한 계층 배치

#### C. 보안
- XSS 취약점 (dangerouslySetInnerHTML, 미검증 사용자 입력)
- 민감 정보 노출
- SQL/Command Injection

#### D. 성능
- 불필요한 리렌더링 (useCallback/useMemo 누락)
- 무한 루프 가능성 (useEffect 의존성)
- 대용량 데이터 처리

#### E. 프로젝트 패턴 준수
- {config.state_management} 사용 패턴
- 서버/클라이언트 상태 관리 패턴 ({config.state_management} 참조)
- 컴포넌트 구조 (Props 타입 위치, hook 순서)

### 4. 리뷰 출력

```markdown
## 코드 리뷰 결과

### 요약
| 심각도 | 개수 | 항목 |
|--------|------|------|
| 🔴 Critical | {N} | {요약} |
| 🟡 Warning | {N} | {요약} |
| 🔵 Info | {N} | {요약} |

### 상세 발견사항

#### 🔴 C-{N}: {제목}
- **파일**: {경로}:{라인}
- **문제**: {설명}
- **수정 제안**: {코드 예시}

#### 🟡 W-{N}: {제목}
{같은 형식}

#### 🔵 I-{N}: {제목}
{같은 형식}

### 긍정적 부분
- {잘된 점 1-2개}
```

### 5. Critic Loop (1회)

| 기준 | 검증 내용 |
|------|-----------|
| **COMPLETENESS** | 모든 변경 파일을 리뷰했는가? 누락된 관점이 있는가? |
| **PRECISION** | 발견사항이 오탐(false positive)이 아닌가? 실제 문제인가? |

FAIL 시: 리뷰 수정 후 최종 출력 갱신.

### 6. 최종 출력

```
🔍 리뷰 완료
├─ 파일: {변경 파일 수}개
├─ 발견: 🔴 {N} / 🟡 {N} / 🔵 {N}
├─ Critic: 1회 완료
└─ 결론: {한 줄 요약}
```

## 주의사항

- **읽기 전용**: 코드를 수정하지 않음. 발견사항만 보고.
- **전체 컨텍스트**: diff 줄만이 아닌 파일 전체를 읽고 맥락 파악 후 리뷰.
- **오탐 주의**: 확실하지 않은 문제는 🔵 Info로 분류.
- **패턴 존중**: 기존 코드베이스 패턴과 다르다고 무조건 지적하지 않음. CLAUDE.md 및 selfish.config.md 기준.
