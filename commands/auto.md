# /selfish:auto — Full Auto 파이프라인

> 기능 설명 하나로 spec → plan → tasks → implement → review → clean을 완전 자동 실행한다.
> 중간 확인 없음. clarify/analyze 스킵. Critic Loop는 각 단계에서 자동 수행.

## 인자

- `$ARGUMENTS` — (필수) 기능 설명 자연어 텍스트

## 설정 로드

**반드시** `.claude/selfish.config.md`를 먼저 읽는다. 이 파일에 정의된 값을 아래에서 `{config.*}`로 참조한다:
- `{config.ci}` — 전체 CI 명령어
- `{config.gate}` — Phase 게이트 명령어
- `{config.architecture}` — 아키텍처 스타일 및 규칙
- `{config.framework}` — 프레임워크 특성 (서버/클라이언트 경계 등)
- `{config.code_style}` — 코드 스타일 규칙
- `{config.risks}` — 프로젝트 고유 위험 패턴
- `{config.mini_review}` — Mini-Review 점검 항목

설정 파일이 없으면: "`.claude/selfish.config.md`가 없습니다. `/selfish:init`으로 프로젝트 설정을 생성하세요." 출력 후 **중단**.

---

## Critic Loop 규칙 (전 Phase 공통)

> Critic Loop의 목적은 산출물의 결함을 **반드시 찾아내는 것**이다. "PASS"만 나열하는 것은 Critic을 실행하지 않은 것과 동일하다.

### 필수 원칙

1. **최소 발견 수**: 각 Critic 회차에서 **기준당 최소 1개의 우려사항, 개선점, 또는 검증 근거**를 기술해야 한다. 문제가 없다면 "왜 문제가 없는지"를 구체적으로 설명한다.
2. **체크리스트 응답**: 각 기준에 대해 구체적 질문에 답변하는 형태로 출력한다. "PASS" 한 단어 금지.
3. **Adversarial Pass**: 매 회차의 마지막에 **"이 산출물이 실패하는 시나리오 1가지"**를 반드시 기술한다. 시나리오가 현실적이면 FAIL로 전환하여 수정한다.
4. **정량적 근거**: "없음", "준수" 같은 정성적 판단 대신, "N개 중 M개 확인", "X줄 중 Y줄 해당" 같은 정량 데이터를 제시한다.

### 출력 형식

```
=== CRITIC {N}/{MAX} ===
[기준1] {질문} → {구체적 답변 + 정량 근거}
  우려: {있으면 기술, 없으면 "왜 없는지" 설명}
[기준2] ...
[ADVERSARIAL] 실패 시나리오: {구체적 시나리오}
  → 현실적? {Y → FAIL + 수정 / N → 근거 기술}
=== 결과: FAIL {N}건 수정 / 또는 PASS (근거 첨부) ===
```

---

## 실행 절차

### Phase 0: 준비

1. `$ARGUMENTS` 비어있으면 → "기능 설명을 입력하세요." 중단
2. 현재 브랜치 확인 → `BRANCH_NAME`
3. Feature 이름 결정 (키워드 2-3개 → kebab-case)
4. **Pipeline Flag 활성화** (Hook 연동):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" start {feature}
   ```
   - Safety Snapshot 자동 생성 (`selfish/pre-auto` git tag)
   - Stop Gate Hook 활성화 (CI 미통과 시 응답 종료 차단)
   - 변경 파일 추적 시작
5. `specs/{feature}/` 디렉토리 생성 → **경로를 `PIPELINE_ARTIFACT_DIR`로 기록** (Clean 스코프용)
6. 시작 알림:
   ```
   🚀 Auto 파이프라인 시작: {feature}
   ├─ 1/6 Spec → 2/6 Plan → 3/6 Tasks → 4/6 Implement → 5/6 Review → 6/6 Clean
   └─ 예상: 전체 자동 실행 (중간 확인 없음)
   ```

### Phase 1: Spec (1/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase spec`

`/selfish:spec`의 로직을 인라인 실행:

1. 코드베이스에서 관련 코드 탐색 (Glob, Grep) — `{config.architecture}` 계층별 탐색
2. `specs/{feature}/spec.md` 생성
3. `[NEEDS CLARIFICATION]` 항목은 **최선의 추정으로 자동 해결** (clarify 스킵)
   - 추정한 항목에 `[AUTO-RESOLVED]` 태그 추가
4. **Critic Loop 1회** (Critic Loop 규칙 준수):
   - COMPLETENESS: 모든 User Story에 수용 시나리오가 있는가? 누락된 요구사항은?
   - MEASURABILITY: 성공 기준이 주관적이지 않고 측정 가능한가? **수치 목표가 있다면 근거를 제시했는가?**
   - INDEPENDENCE: 구현 세부사항(코드, 라이브러리명)이 섞이지 않았는가?
   - EDGE_CASES: 최소 2개 이상 식별했는가? 빠진 경계 조건은?
   - FAIL 항목 → 자동 수정 후 spec.md 업데이트
5. 진행 표시: `✓ 1/6 Spec 완료 (US: {N}개, FR: {N}개, Critic: {FAIL수}건 수정)`

### Phase 2: Plan (2/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase plan`

`/selfish:plan`의 로직을 인라인 실행:

1. spec.md 로드
2. 기술적 불확실성 있으면 → WebSearch/코드탐색으로 자동 해결 → research.md 생성
3. `specs/{feature}/plan.md` 생성
   - **수치 목표(줄 수 등)를 설정할 경우, 구조 분석 기반 추정치를 함께 기술** (예: "함수 A ~50줄, 컴포넌트 B ~80줄 → 합계 ~130줄")
4. **Critic Loop 3회** (Critic Loop 규칙 준수):
   - 기준: COMPLETENESS, FEASIBILITY, ARCHITECTURE, RISK, PRINCIPLES
   - **RISK 기준 필수 점검 항목**:
     - `{config.ci}` 실패 시나리오를 **최소 3가지** 열거하고 대응 방안 기술
     - `{config.risks}`의 모든 패턴을 하나씩 점검
     - `{config.framework}` 특성 (서버/클라이언트 경계 등) 고려
   - **ARCHITECTURE 기준**: 이동/생성되는 파일의 import 경로를 구체적으로 기술하고 `{config.architecture}` 규칙 위반 여부를 사전 검증
   - 매 회차마다 이전 회차에서 놓친 점을 **명시적으로 탐색** ("2회차: 1회차에서 {X}를 놓쳤다. 추가 검토: ...")
5. 진행 표시: `✓ 2/6 Plan 완료 (Critic: {총 FAIL 수정}건, 파일: {N}개)`

### Phase 3: Tasks (3/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase tasks`

`/selfish:tasks`의 로직을 인라인 실행:

1. plan.md 로드
2. Phase별 태스크 분해 (T001, T002, ...)
3. **[P] 병렬 마커 규칙**:
   - 파일 경로가 겹치지 않는 독립 태스크에 `[P]` 마커 부여
   - [P] 태스크는 반드시 Phase 4에서 **Task 도구 병렬 호출로 실행** (선언만 하고 순차 실행 금지)
   - 배치당 최대 5개
4. 커버리지 매핑 (FR → Task)
5. **Critic Loop 1회** (Critic Loop 규칙 준수):
   - COVERAGE: 모든 FR/NFR이 최소 1개 태스크에 매핑되는가?
   - [P] 마커가 붙은 태스크 간 파일 경로 겹침이 없는가?
6. `specs/{feature}/tasks.md` 생성
7. 진행 표시: `✓ 3/6 Tasks 완료 (태스크: {N}개, 병렬: {N}개)`

### Phase 4: Implement (4/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase implement`

`/selfish:implement`의 로직을 인라인 실행:

1. tasks.md 파싱
2. Phase별 실행:
   - **순차 태스크**: 직접 실행
   - **[P] 태스크**: **반드시 Task 도구로 병렬 서브에이전트 위임** (배치 최대 5개). 순차 실행 금지.
     ```
     Task("T012: AudioFadeControl 이동", subagent_type: "general-purpose", ...)
     Task("T013: AudioVolumeControl 이동", subagent_type: "general-purpose", ...)
     → 병렬 실행 → 완료 대기 → 통합
     ```
3. tasks.md 내 각 Implementation Phase(Phase 1, 2, 3...) 완료마다 **3단계 게이트** (모두 필수, 하나라도 생략 시 다음 Phase 진입 불가):

   **Step 1. CI 게이트**: `{config.gate}`
   - 실패 시 자동 수정 (최대 3회)
   - 3회 실패 → 해당 Phase 중단, 사용자에게 보고

   **Step 2. Mini-Review** (정량적 검증 필수):
   - 변경된 파일 목록을 나열하고 **각 파일에 대해** `{config.mini_review}` 항목을 확인
   - 출력 형식:
     ```
     Mini-Review ({N}개 파일):
     - file1.tsx: ✓ 전항목 통과
     - file2.tsx: ⚠ {항목} 위반 → 수정
     - 위반: {M}건 → 수정 후 CI 재실행
     ```
   - 문제 발견 시 → 즉시 수정 후 CI 게이트 재실행

   **Step 3. Auto-Checkpoint** (필수 — 생략 금지):
   - `memory/checkpoint.md`에 아래 정보 기록:
     ```markdown
     ## Checkpoint: {feature} Phase {N}
     - 시각: {timestamp}
     - 완료 태스크: T001~T{N} ({완료}/{전체})
     - 변경 파일: {파일 목록}
     - CI: 통과
     - 다음: Phase {N+1} 또는 계속
     ```
   - checkpoint 미기록 시 다음 Phase 진입 불가

4. tasks.md에 `[x]` 실시간 업데이트
5. 전체 완료 후 `{config.ci}` 최종 검증
   - 통과 시: `"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" ci-pass` (Stop Gate 해제)
6. **Implement 회고**: Plan에서 예측하지 못한 문제가 발생했다면 `specs/{feature}/retrospective.md`에 기록 (Clean에서 memory 반영용)
7. 진행 표시: `✓ 4/6 Implement 완료 ({완료}/{전체} 태스크, CI: ✓, Mini-Review: ✓, Checkpoint: ✓)`

### Phase 5: Review (5/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase review`

`/selfish:review`의 로직을 인라인 실행:

1. 구현된 변경 파일 대상 리뷰 (`git diff HEAD`)
2. 코드 품질, `{config.architecture}` 규칙, 보안, 성능, `{config.code_style}` 패턴 준수 검사
3. **Critic Loop 1회** (Critic Loop 규칙 준수):
   - COMPLETENESS: spec.md의 모든 SC(성공 기준)를 하나씩 대조. 미달 시 구체적 수치 제시.
   - PRECISION: 불필요한 변경이 포함되지 않았는가? 스코프 밖 수정이 있는가?
4. **SC 미달 항목 처리**:
   - 수정 가능 → 자동 수정 시도 → `{config.ci}` 재검증
   - 수정 불가 → 사유와 함께 최종 보고에 명시 (사후 합리화 금지, Plan의 목표 설정 오류로 기록)
5. 진행 표시: `✓ 5/6 Review 완료 (🔴{N} 🟡{N} 🔵{N}, SC 미달: {N}건)`

### Phase 6: Clean (6/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase clean`

구현 및 리뷰 완료 후 아티팩트 정리 및 코드베이스 위생 점검:

1. **아티팩트 정리** (스코프 제한):
   - **현재 파이프라인이 생성한 `specs/{feature}/` 디렉토리만 삭제**
   - 다른 `specs/` 하위 디렉토리가 존재하면 **삭제하지 않음** (사용자에게 존재를 알리기만 함)
   - 파이프라인 중간 산출물은 코드베이스에 남기지 않음
2. **Dead Code 스캔**:
   - 구현 과정에서 발생한 미사용 import 검출 (`{config.lint}`로 확인)
   - 이동/삭제된 파일의 빈 디렉토리 제거
   - 미사용 export 검출 (이동된 코드의 원래 위치 re-export 등)
3. **최종 CI 게이트**:
   - `{config.ci}` 최종 실행
   - 실패 시 자동 수정 (최대 2회)
4. **Memory 업데이트** (해당 시):
   - 파이프라인 중 발견된 재사용 가능한 패턴 → `memory/` 기록
   - `[AUTO-RESOLVED]` 항목이 있었으면 → 결정 사항 `memory/decisions/`에 기록
   - **retrospective.md가 있으면** → Plan 단계의 Critic Loop가 놓친 패턴으로 `memory/` 기록 (다음 실행에서 RISK 점검 항목으로 재활용)
5. **Checkpoint 리셋**:
   - `memory/checkpoint.md` 초기화 (파이프라인 완료 = 세션 목적 달성)
6. **Pipeline Flag 해제** (Hook 연동):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" end
   ```
   - Stop Gate Hook 비활성화
   - 변경 추적 로그 삭제
   - Safety tag 제거 (성공 완료이므로)
7. 진행 표시: `✓ 6/6 Clean 완료 (삭제: {N}개, Dead Code: {N}개, CI: ✓)`

### 최종 출력

```
🏁 Auto 파이프라인 완료: {feature}
├─ Spec: US {N}개, FR {N}개
├─ Plan: Critic {FAIL 수정}건, 리서치 {있음/없음}
├─ Tasks: {전체}개 (병렬 {N}개)
├─ Implement: {완료}/{전체} 태스크, CI ✓, Checkpoint ✓
├─ Review: 🔴{N} 🟡{N} 🔵{N}, SC 미달: {N}건
├─ Clean: 아티팩트 {N}개 삭제, Dead Code {N}개 제거
├─ 변경 파일: {N}개
├─ Auto-Resolved: {N}개 (검토 권장)
├─ Retrospective: {있음/없음}
└─ specs/{feature}/ 정리 완료
```

## 중단 조건

다음 상황에서 파이프라인을 **중단**하고 사용자에게 보고:

1. `{config.ci}` 3회 연속 실패
2. 구현 중 파일 충돌 (다른 브랜치 변경과 겹침)
3. Critical 보안 이슈 발견 (자동 수정 불가)

중단 시:
```
⚠ 파이프라인 중단 (Phase {N}/6)
├─ 원인: {중단 사유}
├─ 완료된 단계: {완료 목록}
├─ 롤백: git reset --hard selfish/pre-auto (구현 전 상태로 복원)
├─ 체크포인트: memory/checkpoint.md (마지막 Phase 게이트 통과 시점)
├─ 아티팩트: specs/{feature}/ (부분 완료, Clean 미실행 시 수동 삭제 필요)
└─ 재개: /selfish:resume → /selfish:implement (체크포인트 기반)
```

## 주의사항

- **Full Auto**: 중간 확인 없이 끝까지 실행. 빠르지만 방향 수정 불가.
- **Auto-Resolved 검토**: `[AUTO-RESOLVED]` 태그가 붙은 항목은 추정치이므로 사후 검토 권장.
- **대규모 기능 주의**: User Story 5개 초과 예상 시 시작 전 경고.
- **기존 코드 우선**: 수정 전 반드시 기존 파일 읽기. 맹목적 생성 금지.
- **프로젝트 규칙 준수**: `selfish.config.md`와 `CLAUDE.md`의 프로젝트 규칙 우선.
- **Critic Loop는 의식이 아니다**: "PASS" 한 줄은 Critic을 실행하지 않은 것과 동일. 반드시 Critic Loop 규칙 섹션의 형식을 따른다.
- **[P] 병렬은 강제다**: tasks.md에 [P] 마커를 붙였으면 반드시 Task 도구로 병렬 실행. 순차로 대체 금지.
- **스코프 외 삭제 금지**: Clean에서 현재 파이프라인이 생성하지 않은 파일/디렉토리를 삭제하지 않는다.
