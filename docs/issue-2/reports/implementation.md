# Issue #2 — Phase 2 Record (role: implementation)

Subject: issue-2
loop_state: landed

## What was done

Executed the phase-1 proposal (`docs/issue-2/proposals/implementation.md`,
approved via `APPROVE issue-2/implementation`) in one batch:

1. Deleted `content-design/agents/warrant-hunter.md` outright (option a).
   Core's `warrant/` plugin (core issue #63) is a separately-installed,
   self-registering plugin (own `agents/warrant-hunter.md`,
   `hooks/hooks.json` with its own SessionStart/UserPromptSubmit/PreToolUse
   entries) — not per-role scoped, so it needs zero local registration
   here. This role's mandate line (문구가 사용자의 실제 결정을 돕는가) and
   hand-off note already live in `content-design/hooks/directive.sh` and
   `README.md`, so nothing role-specific was lost.
2. Deleted `content-design/hooks/trailer-gate.sh` and
   `content-design/hooks/handbook-trigger-gate.sh` outright — role-agnostic
   copies, superseded by core canon's registrations in
   `core/hooks/hooks.json` (core issue #66), which fire globally via
   `CLAUDE_ROLE` injection.
3. Deleted `content-design/hooks/record-fields-gate.sh` — its mechanics are
   now core canon (`core/hooks/record-fields-gate.sh`). Read core's copy to
   confirm what role-specific payload it still needs preserved: it checks
   contract §20's generic fields (what-was-done, why, upstream-basis,
   loop_state, open-findings) plus an optional
   `RECORD_FIELDS_TERMINAL_STATES` env var for per-role terminal
   `loop_state` sets. It does **not** implement a per-role `REQUIRED_FIELDS`
   concept — the old local gate's `["copy-draft", "rationale-per-string",
   "ab-alternative"]` check has no equivalent mechanical hook in core.
   Decision: no new config file needed. content-design's terminal
   `loop_state` set is the default (`landed`), so no
   `RECORD_FIELDS_TERMINAL_STATES` override is required either. The
   required-produces list is preserved as directive text only, in
   `directive.sh`'s `PRODUCES` line (unchanged wording), which is the
   accurate current status: it is documented but no longer mechanically
   gated pending a future core enhancement, if any role ever needs one.
4. Removed the 3 `PreToolUse` gate registrations from
   `content-design/hooks/hooks.json`; kept the `SessionStart` →
   `directive.sh` entry.
5. Rewrote `content-design/hooks/directive.sh` as a stub: sources
   `core/hooks/lib/role-directive.sh` and calls `core_role_directive` with
   this role's four unique values (YOU DECIDE / USE_WHEN / PRODUCES /
   HAND-OFF), passed via plain variable assignments so the file satisfies
   `stub-check.sh`'s structural cap (only source line, var assignments, and
   the one call are allowed — no local case/guard/echo). Confirmed against
   core's own `core/hooks/directive.sh` and `role-directive.sh` that no
   local `CLAUDE_ROLE == "content-design"` guard or local
   `CONTENT_DESIGN_CYCLE_OFF` case statement is needed: `core_role_directive`
   already reads `CLAUDE_ROLE` from the environment directly (uses it
   verbatim as the role token and derives the kill-switch var name from it
   via `tr`), so hardcoding the role in the stub would have been redundant
   boilerplate regrowth, not preservation.
6. Updated `README.md`'s Layout section to drop the 3 deleted files and the
   deleted agent file, and to document where the record-required-fields
   information now lives (directive text only, per item 3 above).
   `content-design/.claude-plugin/plugin.json` needed no change — it does
   not reference any of the deleted files.

## Why

Core issue #63 (warrant-hunt) and core issue #66 (role-agnostic gates +
`role-directive.sh` boilerplate) landed a single canon for behavior this
rulebook had been vendoring as near-identical copies (per this repo's own
file comments, e.g. trailer-gate.sh's header already noted it as pure
role-token substitution). Keeping local copies after canon landed would
either double-fire the gates or silently drift from core's copy over time
(exactly the 38/40-unique-hash drift `stub-check.sh`'s own header
describes). This conversion is also an explicit precondition of this
repo's own upcoming "rulebook 성숙화" issue phase 2 per the issue-2 order
constraint.

## Upstream basis

- Issue: #2 (this repo)
- Approval: issue-level comment `APPROVE issue-2/implementation` (contract
  v3 s19 single-account mode)
- Phase-1 proposal: `docs/issue-2/proposals/implementation.md`
- Core canon read directly from the local checkout at
  `~/tokenmaxxxer/tokenmaxxxer-core` (commit `2fd1fcb`, "deliver
  (implementation): promote role-agnostic rulebook gates to core canon
  (issue-66)"): `core/hooks/lib/role-directive.sh`,
  `core/hooks/record-fields-gate.sh`, `core/hooks/handbook-trigger-gate.sh`,
  `core/hooks/hooks.json`, `core/hooks/tests/stub-check.sh`,
  `warrant/hooks/hooks.json`.

## stub-check.sh confirmation (work item 5)

Ran core canon's `core/hooks/tests/stub-check.sh` against the converted
`content-design/` tree:

```
$ bash core/hooks/tests/stub-check.sh content-design
stub-check: ok — no vendored 'trailer-gate.sh' under content-design
stub-check: ok — no vendored 'record-fields-gate.sh' under content-design
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under content-design
stub-check: ok — no vendored 'parse-check.sh' under content-design
stub-check: ok — content-design/hooks/directive.sh is a role-directive stub
$ echo $?
0
```

PASS.

## Open findings

None outstanding for this batch. One deliberate scope note: item 4's
`RECORD_FIELDS_TERMINAL_STATES` mechanism was not wired for this role
because content-design has no divergent terminal `loop_state` set today
(default `landed` applies) — if that changes, set the env var in this
role's `hooks.json`/`directive.sh` at that time, per core's own
documented convention in `core/hooks/record-fields-gate.sh`.
