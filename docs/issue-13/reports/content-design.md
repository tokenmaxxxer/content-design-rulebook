---
subject: issue-13
role: content-design
loop_state: landed
---

# Issue #13 — Phase 2 Record (role: content-design)

Approved via `APPROVE issue-13/content-design` (single-account mode) on the
issue thread, on top of `docs/issue-13/reports/content-design/survey.md`
(current-state re-audit) and `docs/issue-13/proposals/content-design.md`
(approved phase-1 proposal, conservative drop-in of core issue-75's landed
guard/test/check pattern).

## Copy string scope: none this issue (gate remediation only)

[decision] rationale -> [why] this decision, gate-machinery remediation
only, produces no new user-facing copy: issue #13's requirement is the
source-guard + missing-core test + `compliance-check.sh` wiring core
issue-75 already confirmed and merged, not a per-copy-string content
decision, so no copy string is produced or changed by this issue.

Tone-axis: not applicable, reason: no new user-facing copy in this issue.

A/B variant: not applicable, reason: no new copy this issue to test a
variant against.

self-critique: the rationale, tone-axis, and A/B lines above are each an
explicit "not applicable" statement tied to this issue's actual scope (gate
enforcement machinery, not copy), not a silent omission — checked against
this repo's own decision-rationale/tone-axis/self-critique gates' current
per-section requirements (which this same PR also hardens against a
fail-open core-source failure) before this file was written.

## What was done

Followed `docs/issue-13/proposals/content-design.md` exactly — conservative
drop-in of core PR #77's (issue-75, merged) already-reviewed pattern, no
local variant:

1. **Source guard on all 6 gate/directive scripts.** Every
   `. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/{gate-lib,role-directive}.sh"`
   line in `content-design/hooks/directive.sh`,
   `content-design-ab-spec/hooks/ab-spec-gate.sh`,
   `content-design-decision-rationale/hooks/decision-rationale-gate.sh`,
   `content-design-phase1-basis/hooks/phase1-basis-gate.sh`,
   `content-design-self-critique/hooks/self-critique-gate.sh`, and
   `content-design-tone-axis/hooks/tone-axis-gate.sh` now ends in
   `|| { echo "<name>: cannot source <lib>.sh" >&2; exit 2; }` — the exact
   string core's own 7 gates use. Closes the issue-75-confirmed fail-open
   defect: an unguarded failed `source` previously left every
   `gate_kill_switch_active ... || { exit 0; }` call reading the resulting
   "command not found" (127) as kill-switch-off, silently allowing
   everything when `CLAUDE_PLUGIN_ROOT_CORE` is unreachable.
2. **Missing-core test case added to all 5 gate suites.** Each
   `content-design-*/tests/*.test.sh` now has one more `run_case` asserting
   that `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path (`$WORKDIR/
   no-such-core`) denies (exit 2), reusing each suite's existing `run_case`
   helper and an already-in-scope fixture JSON — no new test
   infrastructure.
3. **`compliance-check.sh` wired into `tests/run-all.sh`.** After the 5
   existing gate suites, the aggregator now invokes core canon's
   `hooks/tests/compliance-check.sh` (referenced via
   `CLAUDE_PLUGIN_ROOT_CORE`, never vendored) against each of the 6 plugin
   `hooks/` directories in turn and folds any non-clean result into the
   overall exit code.
4. **README cross-repo citation clarified.** `README.md:3-5` now appends
   "(in the taxonomy-owning repo, not this one)" to the
   `docs/issue-160/proposals/role-taxonomy.md` citation so a future reader
   does not mistake it for a same-repo ghost file.

Matcher/code coverage (requirement 2) and old-role-name/ghost-file cleanup
(requirement 4's other half) were re-checked against the survey and found
already clean — all 5 `hooks.json` matchers (`Write|Edit|MultiEdit|Bash`)
already cover exactly what each gate's Python branches on, and no old
43-role-taxonomy name or ghost manifest/file entry was found anywhere in
this repo (only archival `docs/issue-1/` phase-1 research mentions
pre-taxonomy terms, not live references). No change needed for either;
recorded here as verified-clean rather than silently skipped.

`gate_bash_write_targets` sh/py parity (core issue-75's other half) does not
apply to this repo's gates: none of the 5 gates' Python payloads call
`gate_lib.gate_bash_write_targets` directly — Bash write targets are
extracted in **bash** and passed to Python via the `GATE_BASH_TARGETS` env
var, so there is no Python-side call site to be out of parity.

## Verification

Full suite, all 5 gate test files plus the missing-core case each, run from
repo root via `tests/run-all.sh`:

| Gate | Cases (incl. missing-core) | Result |
|---|---|---|
| `content-design-phase1-basis` | 14 | 14/14 pass |
| `content-design-decision-rationale` | 17 | 17/17 pass |
| `content-design-tone-axis` | 20 | 20/20 pass |
| `content-design-ab-spec` | 19 | 19/19 pass |
| `content-design-self-critique` | 16 | 16/16 pass |

86/86 cases pass (81 pre-existing + 5 new missing-core cases, one per
suite).

`tests/run-all.sh`'s new `compliance-check.sh` stage, run against
`CLAUDE_PLUGIN_ROOT_CORE=$HOME/tokenmaxxxer/tokenmaxxxer-core/core` (core
PR #77, merged, `deliver(implementation)` for issue-75):

- `content-design/hooks` — no `*-gate.sh` file present (only
  `directive.sh`, which sources `role-directive.sh` not `gate-lib.sh`, so
  `compliance-check.sh`'s own file selector correctly has nothing to
  check) — `PASS` (vacuous).
- `content-design-ab-spec/hooks`, `content-design-decision-rationale/hooks`,
  `content-design-phase1-basis/hooks`, `content-design-self-critique/hooks`,
  `content-design-tone-axis/hooks` — `compliance-check: ok` for each gate,
  exit 0.

`tests/run-all.sh` overall: green (exit 0), all 5 gate suites plus all 6
`compliance-check.sh` invocations pass.

## Self-critique note

Checked the diff against the proposal's four numbered items one by one: (1)
the guard string on all 6 scripts matches core's canon form character for
character (verified against `core/hooks/approval-gate.sh` etc. in the core
checkout, not retyped from memory); (2) each new test case reuses an
existing in-scope fixture rather than inventing new content, matching the
proposal's "no new test infrastructure" constraint; (3)
`compliance-check.sh` is invoked by reference through
`CLAUDE_PLUGIN_ROOT_CORE`, never copied into this repo; (4) the README
change is the single parenthetical clause the proposal specified, nothing
more. Re-ran the full suite after each of the 6 source-guard edits (not
just once at the end) to catch a shell-quoting mistake early — none found.
One residual note carried over from the issue-10 precedent record still
applies here: this session's installed plugin set predates this PR's edits,
so this record's own gate evaluation ran against the working tree's
just-edited gate scripts directly via `tests/run-all.sh`, not through a
live hook re-invocation — the newly guarded/tested gates the record itself
must satisfy are exercised by the test suite above, and this file's own
copy-string section was hand-checked line-by-line against each of the
decision-rationale/tone-axis/self-critique gates' current (already-fixed,
pre-issue-13) regex requirements rather than assumed to pass.

## Open findings

None blocking. The README cross-repo citation (proposal item 4) was the
lowest-priority, doc-only item and is now resolved with the minimal
clarifying clause the proposal specified — no further action pending on any
of the four proposal items.
