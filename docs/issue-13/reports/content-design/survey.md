---
subject: issue-13
role: content-design
phase: 1-survey
---

# Current-state survey — content-design A+ final closure (re-audit)

## Upstream reference (core, landed on main)

- core PR #77 (`tokenmaxxxer/tokenmaxxxer-core`, merged 2026-08-01,
  `deliver(implementation)` for issue-75): mandates a `||`-guarded source
  of `gate-lib.sh` at every gate (`. "$path" || { echo "<gate>: cannot
  source gate-lib.sh" >&2; exit 2; }`), adds a `compliance-check.sh`
  structural rule flagging an unguarded `gate-lib.sh` source, ports
  `gate_bash_write_targets` to `gate-lib.py` (sh/py parity), and adds a
  mandatory 7th `missing-core` test group asserting a gate with
  `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path denies (exit 2),
  not silently allows. Reason: an unguarded `source` failure runs no code
  (no `gate_*` functions defined), so the standard
  `gate_kill_switch_active ... || { exit 0; }` idiom reads the resulting
  "command not found" (127) as kill-switch-off and silently allows
  everything.
- `docs/handbooks/gate-house-standard.md`'s new "Transition note
  (issue-75...)" section explicitly tells every already-migrated rulebook
  to re-pull the guarded source line and re-check with
  `compliance-check.sh`.
- on-the-record PR #182 (CLAUDE_PLUGIN_ROOT_CORE injection in spawn.py)
  not separately inspected — its effect (the env var being reliably set
  in real sessions) does not change what this repo's gate scripts need to
  do; the guard is required regardless of whether the var is normally
  present, precisely for the case it is not.

## This repo's gates — literal defect check

All 6 hook scripts source core canon with **no `||` guard** on the same
statement — the exact issue-75-confirmed defect, unfixed here:

- `content-design/hooks/directive.sh:4` — sources `role-directive.sh`
- `content-design-ab-spec/hooks/ab-spec-gate.sh:10`
- `content-design-decision-rationale/hooks/decision-rationale-gate.sh:10`
- `content-design-phase1-basis/hooks/phase1-basis-gate.sh:10`
- `content-design-self-critique/hooks/self-critique-gate.sh:10`
- `content-design-tone-axis/hooks/tone-axis-gate.sh:10`

All six read `. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh"`
(or `role-directive.sh`) with nothing after it — same shape as core's
pre-issue-75 example that the handbook now calls the fail-open trap.

## missing-core test coverage

None of the 5 gate test files
(`content-design-*/tests/*.test.sh`) exercise `CLAUDE_PLUGIN_ROOT_CORE`
pointed at a nonexistent path. `content-design-ab-spec/tests/ab-spec-gate.test.sh`
was read in full (230 lines, cases a–o) — malformed-JSON, kill-switch,
replace_all, absolute/`./`-path, and Bash-write-coverage cases are all
present, but no case 7 (missing-core). Same gap presumed structurally
identical across the other 4 test files (same harness lineage, same
generation history per `docs/issue-10`).

## gate_bash_write_targets python parity

Not applicable here: no plugin's Python payload calls
`gate_lib.gate_bash_write_targets` directly. `ab-spec-gate.sh` (and, by
inspection of the shared pattern, the other 4 gates) extracts Bash write
targets in **bash** via `gate_bash_write_targets "$INPUT_JSON"` and passes
the token list into Python via the `GATE_BASH_TARGETS` env var — so the
sh/py parity gap core fixed does not affect this repo's gates. No action
needed on this point.

## matcher / code coverage

All 5 gate `hooks.json` files use `"matcher": "Write|Edit|MultiEdit|Bash"`,
and each gate script's Python branches on exactly those 4 tool names
(`Bash` handled separately via `GATE_BASH_TARGETS`, else
`Write|Edit|MultiEdit`). No matcher/code mismatch found — advertised
coverage is reachable in production as written.

## compliance-check.sh

Not present in this repo and not invoked anywhere in
`tests/run-all.sh`. Core's migration checklist (`gate-house-standard.md`
§"For each of the 43 rulebook repos...") calls for running
`compliance-check.sh` against the rulebook's own gates as steps 1 and 4.
This repo has no local record of ever running it, and no wiring to run it
now that it flags the unguarded-source defect above.

## README / manifest — ghost files, old role names

- `.claude-plugin/marketplace.json`: 6 plugin entries, all `source` paths
  resolve to real directories. No ghost entries.
- `README.md`: every in-repo path cited resolves except line 4's
  `docs/issue-160/proposals/role-taxonomy.md` — this is a cross-repo
  citation (the 43-role taxonomy issue lives in a different repo, not
  `content-design-rulebook`; issue-170 is cited the same way in the same
  sentence). Same convention appears to be used elsewhere in this
  ecosystem for provenance citations, so this is not scoped as a
  same-repo ghost-file defect, but it is unverifiable from inside this
  repo alone. Flagged for the proposal as a documentation-only lower-risk
  item.
- No leftover old role-name strings found in `README.md`,
  `marketplace.json`, any `plugin.json`, or any `hooks.json`. Terms like
  "copywriting"/"ux-writer" only occur in archival `docs/issue-1/`
  phase-1 research files, not live references.

## Scout-directive disposition

Skipped. The reference material (core PR #77's merged diff — the actual
guard string, `compliance-check.sh` rule, `gate-lib.py` addition, and the
7th test group — plus this repo's own gate scripts and test harness) is
already fully in hand from the repo/PR content itself; the fix is a
literal drop-in of an already-landed, already-reviewed upstream pattern
with no open design question the spec leaves undecided. This matches the
skip condition (spec leaves no design-decision room) rather than the
"survey is thin/uncertain" trigger for a scout brief.
