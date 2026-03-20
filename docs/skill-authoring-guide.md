# Skill Authoring Guide

> Based on [Anthropic official best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) and [Claude Code skills docs](https://code.claude.com/docs/en/skills). All afc skills MUST follow these rules.

## 1. Conciseness

**SKILL.md는 500줄 이하.** Context window는 공유 자원이다.

Claude는 이미 충분히 똑똑하다. 각 문단에 대해 자문:
- "Claude가 이미 아는 내용인가?" → 삭제
- "이 토큰이 컨텍스트 비용을 정당화하는가?" → 아니면 삭제
- "별도 파일로 빼도 되는가?" → 맞으면 분리

```markdown
# Bad (150 tokens) — Claude에게 PDF 설명 불필요
PDF (Portable Document Format) files are a common file format...

# Good (50 tokens)
Use pdfplumber for text extraction:
```

## 2. Progressive Disclosure

SKILL.md = 개요 + 참조 링크. 상세는 별도 파일.

```
my-skill/
├── SKILL.md              # 개요 (500줄 이하)
├── reference.md           # API/쿼리 등 상세 (필요 시만 로드)
├── templates/             # 출력 템플릿
└── scripts/               # 실행 스크립트
```

**참조 깊이 1단계만.** SKILL.md → reference.md (OK). SKILL.md → A.md → B.md (BAD).

**분리 대상:**
- GraphQL/API 쿼리 (10줄+)
- 출력 템플릿 (20줄+)
- 실행 모드 상세 설명 (30줄+)
- Critic Loop 기준 (docs/critic-loop-rules.md 참조, 인라인 복제 금지)

## 3. Dynamic Context (`!`command``)

스킬 로드 시 셸 명령을 자동 실행하여 결과를 프롬프트에 주입:

```markdown
## Project Config
!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND]"`

## PR Context
!`gh pr view $0 --json url,title,headRefName 2>/dev/null || echo "PR_FETCH_FAILED"`
```

**적용 기준:**
- 스킬이 외부 데이터(config, PR, git status)에 의존 → `!`command`` 사용
- 모델이 매번 같은 명령을 실행하게 되는 패턴 → 프리페치로 전환
- 실패 가능 → 반드시 `|| echo "FALLBACK"` 추가

## 4. Description

```yaml
description: "Terse label — use when the user [trigger phrases]"
```

**규칙:**
- 3인칭 (절대 "I" 또는 "You" 사용 금지)
- "무엇을 하는지" + "언제 사용하는지" 둘 다 포함
- 다른 스킬과 trigger phrase 중복 금지
- 최대 1024자

## 5. Degrees of Freedom

작업의 취약성에 따라 구체성 조절:

| 자유도 | 적합한 경우 | 예 |
|--------|-----------|---|
| **높음** (방향만 제시) | 여러 접근법 유효, 컨텍스트 의존 | 코드 리뷰, 분석 |
| **중간** (패턴 + 파라미터) | 선호 패턴 존재, 약간의 변형 허용 | 테스트 작성, 리포트 |
| **낮음** (정확한 스크립트) | 취약한 작업, 일관성 필수 | DB 마이그레이션, 배포 |

**핵심:** 좁은 다리(한 길만 안전) → 가드레일 필수. 넓은 들판(어디든 OK) → 방향만 제시.

## 6. Feedback Loops

코드 변경이 있는 스킬은 반드시 검증 루프 포함:

```markdown
1. Apply fix
2. Run validation: `{config.test}` or `{config.ci}`
3. If fail → diagnose, fix, go to step 2
4. If pass → proceed
```

read-only 스킬도 "재실행 방법" 명시 (예: "결과 불만족 시 scope 조정 후 재실행").

## 7. Terminology Consistency

프로젝트 전체에서 동일 용어 사용:

| 용어 | 의미 | 사용하지 않을 것 |
|------|------|----------------|
| orchestration mode | 작업 실행 방식 | execution mode, run mode |
| sequential | 1개씩 순차 실행 | single, serial |
| parallel batch | ≤5 병렬 실행 | batch, parallel |
| swarm | 6+ orchestrator 관리 | parallel swarm, review swarm |
| impl-worker | 구현 서브에이전트 | implementation worker, impl worker |
| critic loop | 수렴 기반 검증 | review loop, validation loop |
| config | `.claude/afc.config.md` | settings, preferences |

## 8. Shared References (인라인 복제 금지)

이미 `docs/`에 존재하는 내용은 참조만:

```markdown
# Good — 링크로 참조
Critic Loop rules: see [docs/critic-loop-rules.md](../../docs/critic-loop-rules.md)

# Bad — 같은 내용을 인라인 복제
## Critic Loop
1. GROUND_IN_TOOLS: ...
2. Minimum findings: ...
```

**공유 문서 목록:**
- `docs/critic-loop-rules.md` — Critic Loop 규칙
- `docs/phase-gate-protocol.md` — Phase gate 검증
- `docs/expert-protocol.md` — Expert 에이전트 프로토콜
- `docs/skill-authoring-guide.md` — 이 문서

## 9. Config Load Pattern

외부 데이터 의존 스킬은 `!`command`` 로 프리페치:

```markdown
## Project Config (auto-loaded)
!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND]"`
```

프리페치 실패 시 → 수동 읽기 지시 + `/afc:init` 안내.

## 10. Checklist

스킬 작성/수정 시 확인:

- [ ] SKILL.md 500줄 이하
- [ ] Description: 3인칭 + "무엇" + "언제"
- [ ] 대형 블록 (10줄+) → 별도 파일 참조
- [ ] 참조 깊이 1단계
- [ ] `docs/` 내용 인라인 복제 없음
- [ ] 용어 이 가이드 기준과 일치
- [ ] 코드 변경 스킬 → 피드백 루프 포함
- [ ] 외부 데이터 의존 → `!`command`` 프리페치
- [ ] Claude가 이미 아는 것 설명하지 않음
