# content-design-rulebook

Rulebook for the `content-design` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 문구가 사용자의 실제 결정을 돕는가
- **use_when**: 플로우에 새 카피/마이크로카피가 걸릴 때
- **produces**: copy draft, rationale per string, A/B alternative (if applicable)
- **write_scope**: []
- **hand-off**: 화면/플로우 구조 자체가 바뀌어야 하면 → interaction-design

## Install

```
claude plugin marketplace add tokenmaxxxer/content-design-rulebook
claude plugin install content-design
```

## Layout

- `content-design/.claude-plugin/plugin.json` — plugin manifest
- `content-design/hooks/hooks.json` — SessionStart wiring (directive.sh only)
- `content-design/hooks/directive.sh` — SessionStart role directive; stub that
  sources core canon's `core/hooks/lib/role-directive.sh` and passes this
  role's four unique values (core issue #66)
- `content-design-ab-spec/` — PreToolUse gate: testable A/B variant spec per
  copy string (exactly one varied element + a user-behavior signal, or an
  explicit not-applicable + reason). Scope:
  `docs/issue-<n>/reports/content-design.md`. Kill switch:
  `CONTENT_DESIGN_AB_SPEC_GATE_OFF`
- `content-design-decision-rationale/` — PreToolUse gate: decision-tied
  rationale (`[decision] -> [why]`), basis-level in a phase-1 proposal,
  per-copy-string in the phase-2 record. Scope:
  `docs/issue-<n>/proposals/*content-design*.md` (proposal mode) and
  `docs/issue-<n>/reports/content-design.md` (report mode). Kill switch:
  `CONTENT_DESIGN_DECISION_RATIONALE_GATE_OFF`
- `content-design-phase1-basis/` — PreToolUse gate: a phase-1 proposal must
  state a survey+scout basis (a `docs/issue-<n>/reports/*/survey.md`
  reference, a scout-brief reference, or a documented scout-skip) —
  whole-document check by design, since a phase-1 proposal has no
  per-copy-string headers to section on. Scope:
  `docs/issue-<n>/proposals/*content-design*.md`. Kill switch:
  `CONTENT_DESIGN_PHASE1_BASIS_GATE_OFF`
- `content-design-tone-axis/` — PreToolUse gate: NN Group 4-axis tone check
  per copy string in the phase-2 record, present or explicitly
  skipped-with-reason. Scope: `docs/issue-<n>/reports/content-design.md`.
  Kill switch: `CONTENT_DESIGN_TONE_AXIS_GATE_OFF`
- `content-design-self-critique/` — PreToolUse gate: self-critique note per
  copy string in the phase-2 record, present, genuine (references the
  rationale/tone/A-B content it critiques), and ordered after that content.
  Scope: `docs/issue-<n>/reports/content-design.md`. Kill switch:
  `CONTENT_DESIGN_SELF_CRITIQUE_GATE_OFF`
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

The role-agnostic gates (record-fields, trailer, handbook-trigger) and the
warrant-hunt background agent have no local copies here — they are core
canon, registered globally via `core/hooks/hooks.json` (core issue #66) and
the `warrant/` plugin (core issue #63) and fire for every role through
`CLAUDE_ROLE` injection. This role's required-record-field list (copy draft,
rationale per string, A/B alternative) lives only in `directive.sh`'s
PRODUCES line — core's `record-fields-gate.sh` checks contract §20's
generic fields (what-was-done/why/upstream-basis/loop_state/open-findings),
not a per-role field list, so no separate config file is needed for it.

The 5 content-design gates above each source core issue #72's
`core/hooks/lib/gate-lib.sh` / `gate-lib.py` (reference only, never a
vendored copy — `docs/handbooks/gate-house-standard.md`) for fail-closed
trap handling, kill-switch semantics (only a recognized on-spelling
disables; any unrecognized value stays active), path normalization
(absolute/relative/`./`-prefixed all resolve to the same in-scope tail),
`Write`/`Edit`/`MultiEdit` reconstruction (`replace_all` honored per-edit),
and `Bash`-tool write-target detection (a `Bash` command that would write
to a gated file is denied the same as an equivalent `Write` call, since its
resulting content can't be verified). Each gate keeps its own semantic
`check()` — the doctrine differs per plugin — but every per-copy-string
`check()` requires a section header to exist (denies explicitly rather than
silently checking the whole document) and only searches within that
section's own line window, never the whole-document text.

This is scaffolding, not a finished rulebook: fill in doctrine detail and
handoff enforcement beyond the 5 gates above before treating it as fully
load-bearing.
