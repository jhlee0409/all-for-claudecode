# Phase 완료 게이트 (3단계)

각 Phase 완료 후 **3단계 검증**을 순차 수행한다:

## Step 1. CI 게이트

```bash
{config.gate}
```

- **통과**: Step 2로 진행
- **실패**:
  1. 에러 메시지 분석
  2. 관련 태스크 파일 수정
  3. 재검증
  4. 3회 실패 시 → 사용자에게 보고 후 **중단**

## Step 2. Mini-Review

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

## Step 3. Auto-Checkpoint

Phase 게이트 통과 후 자동으로 세션 상태를 저장한다:

```markdown
# memory/checkpoint.md 자동 업데이트
현재 Phase: {N}/{전체}
완료 태스크: {완료 ID 목록}
변경 파일: {파일 목록}
마지막 CI: ✓
```

- 세션이 중단되어도 `/selfish:resume`로 이 지점부터 재개 가능
