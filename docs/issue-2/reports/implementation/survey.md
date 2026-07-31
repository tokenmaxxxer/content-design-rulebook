# Issue #2 — Phase 1 Survey (role: implementation)

Subject: issue-2

## Issue as written (verbatim work items, translated for this record)

Background: core has landed a single canon —
- warrant-hunt: core's `warrant/` plugin (core issue #63, size-proportional budget + miss-streak + instrumentation)
- the 3 role-agnostic gates (trailer / record-fields / handbook-trigger): `core/hooks/` (core issue #66, CLAUDE_ROLE injection, hook registration lives on the core side)
- shared directive boilerplate: the `core_role_directive` function in `core/hooks/lib/role-directive.sh`

Work items (one batch):
1. Remove this rulebook's warrant-hunter copy (`agents/warrant-hunter.md` and the related hunt-cadence directive) → replace with a reference to core canon.
2. Remove the `trailer-gate.sh` / `record-fields-gate.sh` / `handbook-trigger-gate.sh` copies and their hook registrations (core-side registration replaces them).
3. Replace `directive.sh` with a stub form (source the shared function + call it + role-specific part only) — role-specific content must be preserved.
4. Where a role has a genuine substantive difference (e.g., the set of terminal `loop_state` values), preserve it explicitly via a `RECORD_FIELDS_TERMINAL_STATES`-style setting.
5. Record confirmation that `core/hooks/tests/stub-check.sh` passes.

Ordering constraint: this conversion must complete before this repo's "rulebook maturation" issue's phase 2.

## Current-state survey

Repo root: `content-design-rulebook-issue-2-implementation/` (single-role repo; no `core/` directory present locally — core canon lives in a separate/external repo and is only referenced by comments here).

### Files found

- `content-design/agents/warrant-hunter.md` — role's own warrant-hunter copy.
  - Explicitly says "adapted from implementation-rulebook's `agents/warrant-hunter.md`" — i.e. a role-specific copy of a pattern that (per the issue) now belongs to core's `warrant/` plugin.
  - Contains: role's own YOU-DECIDE line (문구가 사용자의 실제 결정을 돕는가), a scope/hand-off note, and a TODO to "enumerate this role's own stance set before shipping."
  - Role-specific part worth preserving: the mandate line quoting content-design's own decision boundary, and the hand-off note to interaction-design.
  - Not role-specific (candidate for removal/reference-out): the general "rotating stance / one finding / read-only" hunt mechanics — these match core's warrant-hunt description and should not be maintained as a local copy.

- `content-design/hooks/hooks.json` — registers all 4 hooks (SessionStart directive.sh; PreToolUse record-fields-gate.sh, handbook-trigger-gate.sh, trailer-gate.sh) locally.
  - Per issue item 2, the 3 gate registrations (record-fields, handbook-trigger, trailer) should be removed here since core now registers them; only the SessionStart directive entry is role-specific and stays (in stub form per item 3).

- `content-design/hooks/trailer-gate.sh` — full copy of the trailer-gate logic.
  - Its own header comment says "Adapted from implementation-rulebook's trailer-gate.sh, role name substituted only (this file's logic is role-agnostic)" — i.e. this file is explicitly a gate copy with no role-specific logic. Direct removal candidate per item 2.

- `content-design/hooks/record-fields-gate.sh` — full copy of record-fields gate logic, but with role-specific payload: `REQUIRED_FIELDS = ["copy-draft", "rationale-per-string", "ab-alternative"]` sourced from this role's own `produces` list (per its comment: "adapted per issue-170 from roles/content-design.json's `produces`, NOT copied from another role's field set").
  - This is the clearest case of item 4: the mechanics (gate script) are role-agnostic and should collapse to core canon + registration, but the required-field set (and, if this role ever defines terminal loop states, a `RECORD_FIELDS_TERMINAL_STATES`-equivalent) is role-specific and must be preserved as configuration, not as forked logic.

- `content-design/hooks/handbook-trigger-gate.sh` — mostly a placeholder/skeleton (verdict is a hardcoded `exit 0` with a TODO), role-agnostic mechanics. Removal candidate per item 2; no role-specific payload found here yet (skeleton has not been hardened per this role's `write_scope: []`).

- `content-design/hooks/directive.sh` — SessionStart hook.
  - Role-specific content to preserve: the YOU_DECIDE / USE_WHEN / PRODUCES / WRITE_SCOPE / HAND-OFF lines, the RECORD path, and the `CONTENT_DESIGN_CYCLE_OFF` kill-switch variable name.
  - Boilerplate to stub out per item 3: the "on top of core's protocol" framing, the phase-gating restatement of contract v3 s19, and the general structure — these should be produced by calling a shared `core_role_directive` function (from `core/hooks/lib/role-directive.sh`) with this role's specific values passed as arguments, rather than a hand-written heredoc duplicating the shared format.

- `content-design/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — plugin/marketplace manifests. No warrant-hunter/gate content; out of scope for this issue's 5 items, left untouched.

- `docs/specs/approvers.md` — empty allowlist stub, unrelated to this issue's scope.

### What is genuinely role-specific (must survive the conversion)

- The `decides` / `use_when` / `produces` / `write_scope` / `hand-off` quintet (currently duplicated in README.md, plugin.json's description, and directive.sh — all three already agree and should keep agreeing).
- `REQUIRED_FIELDS` list in record-fields-gate.sh (copy-draft / rationale-per-string / ab-alternative).
- `CONTENT_DESIGN_CYCLE_OFF` kill-switch env var name and the `CLAUDE_ROLE = "content-design"` guard value.
- The warrant-hunter mandate line and its hand-off note.
- The RECORD path `docs/issue-<n>/reports/content-design.md`.

### What is a pure gate/hunt copy (candidate for removal → core canon reference)

- `trailer-gate.sh` in full (its own comment says role-agnostic).
- `handbook-trigger-gate.sh` mechanics (skeleton, no role payload yet).
- `record-fields-gate.sh` mechanics (the deny/python-eval scaffolding), separate from its `REQUIRED_FIELDS` payload.
- `warrant-hunter.md`'s general hunt-cadence mechanics (rotating stance, one-finding rule, read-only scope), separate from the role's own mandate line.
- The 3 gate hook registrations in `hooks.json`.

## Scouting

This repo hosts a single role (`content-design`) with no other role's rulebook checked out locally to compare against, and no `core/` directory present to inspect directly — core canon is referenced only by name/path in comments (`core/hooks/`, `core/hooks/lib/role-directive.sh`, `core/hooks/tests/stub-check.sh`, core issues #63/#66). This is a pure internal consistency/refactor task converging this rulebook onto an already-decided external canon, not an open design choice with competing in-repo patterns to reconcile — so external/comparative scouting is skipped. (Executing phase 2 will need read access to the core canon repo to get the actual shared function signature and stub-check.sh contract; that is a phase-2 concern, flagged here for the record.)
