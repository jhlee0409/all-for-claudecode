# /selfish:implement — 코드 구현 실행

> tasks.md의 태스크를 Phase별로 실행한다.
> 병렬 가능한 태스크([P])는 Agent Teams로 동시 실행하고, Phase 완료 시 CI 게이트를 통과해야 한다.

## 인자

- `$ARGUMENTS` — (선택) 특정 태스크 ID 또는 Phase 지정 (예: `T005`, `phase3`)

## 설정 로드

**반드시** `.claude/selfish.config.md`를 먼저 읽는다. 설정 파일이 없으면 중단.

## 실행 절차

### 0. Safety Snapshot

구현 시작 전 **롤백 포인트**를 생성한다:

```bash
git tag -f selfish/pre-implement
```

- 실패 시 `git reset --hard selfish/pre-implement`로 즉시 롤백 가능
- 태그는 다음 `/selfish:implement` 실행 시 자동 덮어씌워짐
- `/selfish:auto` 파이프라인 내에서 실행 시 `selfish/pre-auto` 태그가 이미 존재하므로 생략

### 1. 컨텍스트 로드

1. **현재 브랜치** → `BRANCH_NAME`
2. `specs/{feature}/` 에서 다음 파일 로드:
   - **tasks.md** (필수) — 없으면 중단: "tasks.md가 없습니다. `/selfish:tasks`를 먼저 실행하세요."
   - **plan.md** (필수) — 없으면 중단
   - **spec.md** (참고용)
   - **research.md** (있으면)
3. tasks.md 파싱:
   - 각 태스크의 ID, [P] 마커, [US*] 라벨, 설명, 파일 경로 추출
   - Phase별 그룹화
   - 이미 완료된 `[x]` 태스크 식별

### 2. 진행 상태 확인

- 완료된 태스크가 있으면 상태 표시:
  ```
  진행 상태: {완료}/{전체} ({퍼센트}%)
  다음: {미완료 첫 태스크 ID} - {설명}
  ```
- `$ARGUMENTS`로 특정 태스크/Phase 지정 시 해당 항목부터 시작

### 3. Phase별 실행

각 Phase를 순서대로 실행한다:

#### Phase 실행 규칙

1. **순차 태스크** (P 마커 없음):
   - 하나씩 순서대로 실행
   - 각 태스크 시작 시: `▶ {ID}: {설명}`
   - 완료 시: `✓ {ID} 완료`

2. **병렬 태스크** ([P] 마커):
   - 같은 Phase 내 연속된 [P] 태스크를 **배치 단위**(최대 5개)로 그룹화
   - **파일 겹침 없음** 확인 (겹치면 순차로 강등)
   - Task 도구로 병렬 서브에이전트 위임:
     ```
     TaskCreate({
       description: "{ID}: {설명}",
       prompt: "다음 태스크를 구현하세요:\n\n## 태스크\n{설명}\n\n## 관련 파일\n{파일 경로}\n\n## Plan 컨텍스트\n{plan.md에서 관련 섹션}\n\n## 코드 스타일\n- {config.code_style} 규칙\n- {config.architecture} 규칙 준수\n- CLAUDE.md 및 selfish.config.md 규칙 따르기",
       subagent_type: "general-purpose"
     })
     ```
   - 모든 배치 완료 대기 후 다음 배치/Phase 진행

3. **의존성 준수**:
   - 태스크 설명에 `after T{ID}` 또는 `requires T{ID}`가 있으면 해당 태스크 완료 후 실행
   - Phase 순서는 반드시 지킴

#### Phase 완료 게이트 (3단계)

각 Phase 완료 후 **3단계 검증**을 순차 수행한다:

**Step 1. CI 게이트**:

```bash
{config.gate}
```

- **통과**: Step 2로 진행
- **실패**:
  1. 에러 메시지 분석
  2. 관련 태스크 파일 수정
  3. 재검증
  4. 3회 실패 시 → 사용자에게 보고 후 **중단**

**Step 2. Mini-Review**:

Phase 내 변경 파일 대상 `{config.mini_review}` 항목을 정량적으로 점검:
- 변경된 파일 목록을 나열하고 **각 파일에 대해** 점검 수행
- 출력 형식:
  ```
  Mini-Review ({N}개 파일):
  - file1.tsx: ✓ 전항목 통과
  - file2.tsx: ⚠ {항목} 위반 → 수정
  - 위반: {M}건 → 수정 후 CI 재실행
  ```
- 문제 발견 시 → 즉시 수정 후 CI 게이트(Step 1) 재실행
- 문제 없으면 → `✓ Phase {N} Mini-Review 통과`

**Step 3. Auto-Checkpoint**:

Phase 게이트 통과 후 자동으로 세션 상태를 저장한다:

```markdown
# memory/checkpoint.md 자동 업데이트
현재 Phase: {N}/{전체}
완료 태스크: {완료 ID 목록}
변경 파일: {파일 목록}
마지막 CI: ✓
```

- 세션이 중단되어도 `/selfish:resume`로 이 지점부터 재개 가능

### 4. 태스크 실행 패턴

각 태스크에서:

1. **파일 읽기**: 수정할 파일이 있으면 반드시 먼저 읽기
2. **구현**: plan.md의 설계를 따라 코드 작성
3. **타입 확인**: 새 코드가 TypeScript strict 모드에 맞는지 확인
4. **tasks.md 업데이트**: 완료된 태스크를 `[x]`로 마크
   ```markdown
   - [x] T001 {설명}  ← 완료
   - [ ] T002 {설명}  ← 미완료
   ```

### 5. 최종 검증

모든 태스크 완료 후:

```bash
{config.ci}
```

- **통과**: 최종 보고서 출력
- **실패**: 에러 수정 시도 (최대 3회)

### 6. 최종 출력

```
🚀 구현 완료
├─ 태스크: {완료}/{전체}
├─ Phase: {Phase 수}개 완료
├─ CI: ✓ {config.ci} 통과
├─ 변경 파일: {파일 수}개
└─ 다음 단계: /selfish:review (선택)
```

## 주의사항

- **기존 코드 우선 읽기**: 수정 전 반드시 파일 내용 확인. 맹목적 코드 생성 금지.
- **과도한 변경 금지**: plan.md에 없는 리팩토링/개선 하지 않기.
- **아키텍처 준수**: {config.architecture} 규칙 준수.
- **{config.ci} 게이트**: Phase 완료 시 반드시 통과. 우회 금지.
- **Agent Teams 배치**: 최대 5개. 파일 겹침 절대 금지.
- **오류 시**: 무한 루프 방지. 3회 시도 후 사용자에게 상황 보고.
- **tasks.md 실시간 업데이트**: 태스크 완료마다 체크박스 마크.
