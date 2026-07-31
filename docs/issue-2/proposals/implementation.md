# Issue #2 — Phase 1 Proposal (role: implementation)

Subject: issue-2

This is a phase-1 proposal only: research + recommended plan. No execution
happens under this document; phase 2 (actual file edits) requires an
Approve per contract v3 s19, recorded in `docs/specs/approvers.md`, before
anyone opens `docs/issue-2/reports/implementation.md`.

Precondition for phase 2: read access to the core canon repo, to confirm
the actual signature of `core_role_directive` (in
`core/hooks/lib/role-directive.sh`), the exact registration surface core
provides for the 3 gates and the warrant-hunt plugin, and the pass
criteria of `core/hooks/tests/stub-check.sh`. This proposal assumes a
reasonable shape for those based on the issue text and the file comments
already in this repo (several files say "adapted from
implementation-rulebook's X, role name substituted only" — i.e. this repo's
own history already documents these as copies of a shared pattern).

## Work item 1 — warrant-hunter

File: `content-design/agents/warrant-hunter.md`

Proposal: delete this file. Replace with either (a) nothing, if core's
`warrant/` plugin is installed at the marketplace/root level and covers
every role automatically, or (b) a short pointer file (few lines) noting
that hunt coverage for this role comes from core's `warrant/` plugin,
carrying only the role-specific mandate line and hand-off note that don't
exist anywhere else in this repo:

- `문구가 사용자의 실제 결정을 돕는가` (mandate / decision boundary)
- hand-off: 화면/플로우 구조 자체가 바뀌어야 하면 → interaction-design

Decision on (a) vs (b) depends on how core's warrant plugin is scoped
(global vs per-role registration) — needs confirming against the core repo
in phase 2. Update `README.md`'s Layout section to drop the
`agents/warrant-hunter.md` line (or repoint it), and update
`content-design/.claude-plugin/plugin.json` if it declares an `agents`
capability referencing this file.

## Work item 2 — gate copies + hook registrations

Files: `content-design/hooks/trailer-gate.sh`,
`content-design/hooks/record-fields-gate.sh`,
`content-design/hooks/handbook-trigger-gate.sh`,
`content-design/hooks/hooks.json`

Proposal:
- Delete `trailer-gate.sh` outright — its own header already states the
  logic is role-agnostic with only the role name substituted; core's
  version (with CLAUDE_ROLE injection per core issue #66) supersedes it
  with no role-specific payload lost.
- Delete `handbook-trigger-gate.sh` outright — currently a skeleton with a
  hardcoded `exit 0` placeholder verdict and no role-specific payload
  hardened yet; nothing to preserve.
- For `record-fields-gate.sh`: delete the gate mechanics but preserve the
  role-specific payload — the `REQUIRED_FIELDS` list
  (`copy-draft`, `rationale-per-string`, `ab-alternative`) — as
  configuration consumed by core's gate (see work item 4 for the proposed
  mechanism).
- In `hooks.json`, remove the 3 `PreToolUse` hook registrations for these
  gates (record-fields-gate.sh, handbook-trigger-gate.sh, trailer-gate.sh).
  Core issue #66 registers these hooks on the core side via CLAUDE_ROLE
  injection, so duplicate registration here would either double-fire the
  gates or drift from core's copy over time. Keep the `SessionStart`
  registration for `directive.sh` (stubbed per work item 3).
- Update `README.md`'s Layout list to drop the 3 deleted files and note
  that gating now comes from core, with a link/reference to where the
  role-specific `REQUIRED_FIELDS` config lives instead.

## Work item 3 — directive.sh stub

File: `content-design/hooks/directive.sh`

Proposal: replace the current hand-written heredoc (which duplicates the
shared directive format) with a stub that:
1. Sources `core/hooks/lib/role-directive.sh`.
2. Calls `core_role_directive` with this role's specific values as
   arguments/env: role id (`content-design`), YOU_DECIDE, USE_WHEN,
   PRODUCES, WRITE_SCOPE, HAND-OFF, RECORD path, and the kill-switch var
   name `CONTENT_DESIGN_CYCLE_OFF`.
3. Preserves the existing guard (`CLAUDE_ROLE = "content-design"` check)
   and the `CONTENT_DESIGN_CYCLE_OFF` env var name — these are the
   role-specific parts and per the issue text must not be lost.

Exact call signature is unknown until core's `role-directive.sh` is read
in phase 2; this proposal fixes which values are role-owned vs
shared-boilerplate so phase 2 execution is a mechanical fill-in rather
than a design decision.

## Work item 4 — explicit preservation of role-specific gate differences

Proposal: introduce a `RECORD_FIELDS_TERMINAL_STATES`-style explicit
setting (naming to match whatever convention core's gate expects) that
carries this role's `REQUIRED_FIELDS` list
(`copy-draft`, `rationale-per-string`, `ab-alternative`) forward once
`record-fields-gate.sh`'s mechanics move to core. Likely home: a small
config block either inside the stubbed `directive.sh` or a new minimal
`content-design/hooks/role-fields.sh` (or `.json`) sourced by core's gate
via CLAUDE_ROLE — exact shape depends on what core's gate reads (env var
vs config file), to be confirmed in phase 2 against the core repo. No
other role-specific gate divergence (e.g. terminal loop_state set) was
found in this repo's current files — `content-design`'s `write_scope` is
empty and no loop_state handling exists yet, so nothing else needs
preserving under this item at this time.

## Work item 5 — stub-check.sh confirmation

Proposal: phase 2 execution must run `core/hooks/tests/stub-check.sh`
against the converted rulebook and record the pass/fail result (with
command output or a summary) in the phase-2 record
(`docs/issue-2/reports/implementation.md`, opened only after Approve).
This phase-1 document cannot satisfy item 5 itself since it requires the
converted files and the core repo checked out.

## File-by-file summary

| File | Action |
|---|---|
| `content-design/agents/warrant-hunter.md` | delete or shrink to role-specific pointer only |
| `content-design/hooks/trailer-gate.sh` | delete |
| `content-design/hooks/handbook-trigger-gate.sh` | delete |
| `content-design/hooks/record-fields-gate.sh` | delete mechanics; carry `REQUIRED_FIELDS` payload forward as config |
| `content-design/hooks/hooks.json` | remove 3 gate `PreToolUse` registrations; keep `SessionStart` directive entry |
| `content-design/hooks/directive.sh` | replace with stub sourcing `core_role_directive`, passing role-specific values only |
| `README.md` | update Layout section to match the above |
| `content-design/.claude-plugin/plugin.json` | update if it references any deleted file |
| new: role-fields config (exact filename TBD in phase 2) | carries `RECORD_FIELDS`-equivalent role payload |

## Open questions for phase 2 (not decidable from this repo alone)

1. Exact function signature of `core_role_directive`.
2. Whether core's warrant plugin and 3 gates self-register per role via
   CLAUDE_ROLE with zero local registration needed, or whether some
   minimal per-role opt-in file is still required here.
3. Exact config surface core's record-fields gate expects for role-specific
   required fields (env var, JSON file, etc.) — determines work item 4's
   final shape.
4. `core/hooks/tests/stub-check.sh`'s pass criteria, so phase 2 knows what
   "passes" means before recording it per item 5.
