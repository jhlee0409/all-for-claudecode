# /selfish:principles — 프로젝트 원칙 관리

> 프로젝트의 핵심 원칙(constitution)을 생성하고 관리한다.
> memory/principles.md에 저장되어 모든 세션에서 참조된다.

## 인자

- `$ARGUMENTS` — (선택) 동작 지시:
  - 미지정: 현재 원칙 조회
  - `add {원칙}`: 새 원칙 추가
  - `remove {번호}`: 원칙 제거
  - `init`: 대화형 초기 설정

## 설정 로드

**반드시** `.claude/selfish.config.md`를 먼저 읽는다. 설정 파일이 없으면 중단.

## 실행 절차

### 1. 현재 상태 확인

`memory/principles.md` 읽기:
- 있으면: 기존 원칙 로드
- 없으면: 빈 상태 (init 안내)

### 2. 동작 분기

#### A. 조회 (인자 없음)
현재 원칙 목록을 표시:
```
📜 프로젝트 원칙
├─ MUST-001: {원칙}
├─ MUST-002: {원칙}
├─ SHOULD-001: {원칙}
└─ 마지막 수정: {날짜}
```

#### B. 초기 설정 (`init`)

대화형으로 원칙 수집:

1. **프로젝트 컨텍스트** 분석 (CLAUDE.md, package.json, 코드 구조)
2. 자동 추출 가능한 원칙 제안:
   - {config.architecture} 규칙 준수
   - {config.code_style} 준수
   - 린트 경고 0 ({config.lint} 기준)
   - 등
3. 사용자에게 추가 원칙 질문 (AskUserQuestion)
4. 수집된 원칙을 구조화

#### C. 추가 (`add`)
1. 새 원칙의 강도 결정 (MUST / SHOULD / MAY)
2. principles.md에 추가
3. 버전 업데이트

#### D. 제거 (`remove`)
1. 해당 원칙 확인
2. 사용자 확인 후 제거
3. 버전 업데이트 (MAJOR)

### 3. 저장 형식

```markdown
# Project Principles

> Version: {MAJOR.MINOR.PATCH}
> Last Updated: {YYYY-MM-DD}

## MUST (위반 불가)
- **MUST-001**: {원칙} — {근거}
- **MUST-002**: {원칙} — {근거}

## SHOULD (강력 권장)
- **SHOULD-001**: {원칙} — {근거}

## MAY (선택적)
- **MAY-001**: {원칙} — {근거}

## Changelog
- {날짜}: {변경 내용}
```

### 4. 버전 규칙

- **MAJOR**: MUST 원칙 추가/제거/재정의
- **MINOR**: SHOULD/MAY 원칙 추가, MUST 명확화
- **PATCH**: 오타 수정, 근거 보완

## 주의사항

- **영속 저장**: memory/principles.md에 저장되어 세션 간 유지.
- **자동 참조**: /selfish:plan, /selfish:architect에서 자동으로 로드하여 검증.
- **간결하게**: 원칙은 10개 이내로 유지. 너무 많으면 실효성 저하.
- **CLAUDE.md와 중복 방지**: CLAUDE.md에 이미 있는 규칙은 원칙으로 중복 등록하지 않음.
