# Issue #1 — Current-State Survey (role: content-design)

Subject: issue-1

## What exists today

- `content-design/hooks/directive.sh`: hand-written `core_role_directive`
  call (not yet converted to the core-canon stub pattern that issue-2
  landed for the `implementation` role — that conversion is this repo's
  issue-2, already merged for `implementation` only, not yet mirrored
  here). Carries:
  - `YOU_DECIDE`: 문구가 사용자의 실제 결정을 돕는가
  - `USE_WHEN`: 플로우에 새 카피/마이크로카피가 걸릴 때
  - `PRODUCES`: copy draft, rationale per string, A/B alternative (if
    applicable)
  - `HAND_OFF`: 화면/플로우 구조 자체가 바뀌어야 하면 → interaction-design
- `content-design/hooks/hooks.json`: registers only the `SessionStart` →
  `directive.sh` hook. No `PreToolUse` gates present locally (already
  slim — either never vendored the trailer/record-fields/handbook-trigger
  gates this repo's `implementation` role had before its issue-2 cleanup,
  or they were removed earlier).
- `content-design/.claude-plugin/plugin.json`: role metadata only (name,
  description, author). No `agents` block, no warrant-hunter file present
  under `content-design/` — canon warrant-hunt coverage (core issue #63)
  already applies with nothing to delete here, unlike `implementation`'s
  pre-issue-2 state.
- No `content-design/agents/` directory exists.
- `docs/issue-1/` did not exist before this session (created for phase 1
  output).
- No prior content-design phase-1 proposal or phase-2 record exists
  anywhere in the repo (`docs/issue-2/*` are all `implementation`-role
  files).

## Precedent from this repo (issue-2, role: implementation)

`docs/issue-2/proposals/implementation.md` and
`docs/issue-2/reports/implementation.md` are this repo's only completed
phase-1→phase-2 cycle. Observed proposal shape: numbered "work item"
sections, each with target file(s), a proposal, and reasoning; a
file-by-file summary table; an explicit "open questions for phase 2"
section listing what phase-1 could not resolve without core-repo access.
Observed record shape: "what was done" (numbered, mirroring proposal
items), "why", "upstream basis" (issue, approval string, proposal path,
exact core-canon commit/paths read), and a verification section running
the relevant check script with captured output. This is a strong shape
precedent to reuse for methodology-and-format consistency, even though
issue-1's proposal is about content **methodology**, not plugin-file
mechanics.

## Gaps this issue is meant to close (per issue text)

1. `PRODUCES` names 3 deliverable pieces (copy draft, rationale per
   string, A/B alternative) but no document says **how** to produce an
   adequate rationale, what structure a phase-1 proposal for a content
   change must follow, or what phase-2 deliverable structure is required
   beyond the field list.
2. No plugin-level enforcement (directive text is documentation only —
   confirmed pattern from issue-2's phase-2 record: core's
   record-fields-gate has no per-role required-fields mechanism) ties the
   PRODUCES list to an actual gate.
3. warrant-hunter is referenced by the issue's constraints section as
   "reference only, no copy" — confirmed already true here (no local
   warrant-hunter file exists to accidentally duplicate).

These three gaps are what the scout sweep (`scout-brief.md`) aims at.
