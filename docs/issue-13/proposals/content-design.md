---
subject: issue-13
role: content-design
phase: 1-proposal
---

# Proposal — A+ final closure: conservative remediation of re-audit residuals

## Decision

[decision] apply core issue-75's landed guard/test/check pattern verbatim
-> [why] the re-audit found the exact issue-75-confirmed fail-open defect
still unfixed in this repo's 6 gate/directive scripts, and copying the
already-merged upstream form (guarded source line, missing-core test
group, `compliance-check.sh` wiring) closes it with minimum risk versus
inventing a local variant.

## Basis

Survey: `docs/issue-13/reports/content-design/survey.md`. Scout: skipped
(recorded in the survey's "Scout-directive disposition" section) — the
fix target is core PR #77 (`tokenmaxxxer/tokenmaxxxer-core`, merged,
issue-75), an already-landed, already-reviewed upstream pattern with no
remaining design-decision surface for this repo to resolve; that matches
the scout-skip condition for a spec that leaves no design-decision room,
not the "survey too thin" trigger.

## What's wrong (from the survey)

1. All 6 gate/directive scripts source core canon with no `||` guard —
   the issue-75-confirmed fail-open defect (unguarded `source` failure
   defines no `gate_*` functions, so the standard
   `gate_kill_switch_active ... || { exit 0; }` idiom reads the resulting
   127 as kill-switch-off and silently allows everything when core is
   unreachable).
2. None of the 5 gate test suites exercise the missing-core case
   (`CLAUDE_PLUGIN_ROOT_CORE` pointed nowhere must deny, not allow).
3. `compliance-check.sh` (core canon, now flags exactly defect 1) is
   never invoked against this repo's own gates, so nothing here would
   have caught defect 1 mechanically.
4. `README.md:4` cites a cross-repo doc path
   (`docs/issue-160/proposals/role-taxonomy.md`) that cannot be verified
   from inside this repo. Lower-risk documentation item, not a same-repo
   ghost file or an old role name.

Not found (confirmed clean, no action needed): matcher/code coverage
mismatch (all 5 `hooks.json` matchers already cover exactly what each
gate's Python branches on), `gate_bash_write_targets` sh/py parity gap
(this repo's gates never call the Python side of that function — they
extract in bash and pass tokens via env var), old role-name references,
and ghost plugin/manifest entries.

## Proposed changes (conservative — drop-in of core's confirmed form only)

### 1. Guard the source line in all 6 scripts

For each of:
- `content-design/hooks/directive.sh`
- `content-design-ab-spec/hooks/ab-spec-gate.sh`
- `content-design-decision-rationale/hooks/decision-rationale-gate.sh`
- `content-design-phase1-basis/hooks/phase1-basis-gate.sh`
- `content-design-self-critique/hooks/self-critique-gate.sh`
- `content-design-tone-axis/hooks/tone-axis-gate.sh`

change:
```
. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh"
```
to the exact guarded form core's `gate-house-standard.md` now documents
as the only sanctioned usage:
```
. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
```
(`directive.sh` sources `role-directive.sh` instead of `gate-lib.sh`;
same guard shape, same `|| { echo ...; exit 2; }` pattern, message naming
`directive.sh`.) One-line change per file, no other line touched — this
is the entire scope of core's own issue-75 fix applied to its own 7
gates, so the same minimal diff shape applies here.

### 2. Add the missing-core test group to each of the 5 gate test suites

Port core's 7th mandatory group (`run-gate-lib-tests.sh`'s
`missing-core` case) into each `content-design-*/tests/*.test.sh`: run
the gate with `CLAUDE_PLUGIN_ROOT_CORE` pointed at
`"$WORKDIR/no-such-core"` (nonexistent) and assert exit 2 (deny), not
exit 0 (allow). Use each suite's existing `run_case` helper and
env-prefix mechanism already in place for the kill-switch cases (e.g.
`ab-spec-gate.test.sh`'s case g/h) — no new test infrastructure needed,
just one more `run_case` call per file plus a one-line comment citing
issue-75/issue-13.

### 3. Wire `compliance-check.sh` into `tests/run-all.sh`

Add an invocation of core canon's
`"${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/tests/compliance-check.sh"`
against this repo's own hooks directories (one call per plugin, or one
call against the repo root if `compliance-check.sh` supports multiple
gate files per invocation — confirm the exact interface against core's
script signature at implementation time), following the same
`CLAUDE_PLUGIN_ROOT_CORE`-fallback convention the gate scripts already
use. This closes the "nothing here would have caught defect 1
mechanically" gap and matches core's own migration checklist steps 1/4.

### 4. README cross-repo citation

No code or structural change proposed. Recommend appending a one-clause
parenthetical to `README.md:4` noting the path is a cross-repo citation
(e.g. "in the taxonomy-owning repo, not this one") so a future reader
does not treat it as a same-repo ghost-file defect. Deferred to
implementation's judgment on exact wording; not a gate-relevant or
test-relevant change, lowest priority of the four.

## Why this scope and no more

Conservative by design: every change either (a) copies core's exact,
already-approved-and-merged string/pattern verbatim, or (b) is a doc
clarification with no functional effect. No new gate logic, no new scope
regex, no new kill-switch semantics, no restructuring of the 5-gate
layout — the re-audit found process/wiring gaps against an already-
settled upstream standard, not doctrine defects, so the remediation
matches that shape.

## Rejected alternative

Writing a repo-local variant of the `||` guard message or test case
(e.g. a shared helper function instead of the inline `|| { ... }` at
each call site) was considered and rejected: core's own 7 gates use the
identical inline form at every call site with no shared-helper
indirection, and the survey found no reason this repo's 6 sites need to
diverge from that — matching core's canon exactly keeps future
`compliance-check.sh` runs (item 3) trivially green instead of requiring
a custom detection rule.

## Phase-2 status

Not started. This proposal is phase-1 only per role-handoff contract v3
s19; phase-2 implementation is gated on `APPROVE issue-13/content-design`
from a `docs/specs/approvers.md`-listed account, not included in this
session's scope.
