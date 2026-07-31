---
subject: issue-7
role: content-design
loop_state: landed
---

# Issue #7 — Phase 2 Record (role: content-design)

Approved via `APPROVE issue-7/content-design` (single-account mode) on
the issue thread, on top of the approver's FEEDBACK requiring a plugin
set (not a single deepened gate/directive).

## What was done

Basis (upstream): `docs/issue-7/proposals/content-design.md` (phase-1
proposal, rev. 2, approved), itself resting on
`docs/issue-7/reports/content-design/survey.md` and
`docs/issue-7/reports/content-design/scout-brief.md`. Canon scripts
referenced only, never copied (`pricing/hooks/methodology-gate.sh` and
`implementation-rulebook`'s `coding-progress-gate.sh`/`state.sh` are
external design models, not vendored files).

Implemented the proposal's §0 plugin set exactly as specified — five
independent, self-contained plugins, each owning one issue-1 methodology
component, none invoking another's script:

| Plugin | Files | Test result |
|---|---|---|
| `content-design-phase1-basis` | `.claude-plugin/plugin.json`, `hooks/phase1-basis-gate.sh`, `hooks/hooks.json`, `tests/phase1-basis-gate.test.sh` | 5/5 pass |
| `content-design-decision-rationale` | same shape, `hooks/decision-rationale-gate.sh` | 7/7 pass |
| `content-design-tone-axis` | same shape, `hooks/tone-axis-gate.sh` | 8/8 pass |
| `content-design-ab-spec` | same shape, `hooks/ab-spec-gate.sh` | 7/7 pass |
| `content-design-self-critique` | same shape, `hooks/self-critique-gate.sh` | 6/6 pass |

All five gates share the proposal's (2) shape: fail-closed trap-at-top,
own kill switch per plugin (`CONTENT_DESIGN_<NAME>_GATE_OFF`, standard
`""|0|false|no|off` = not-off convention), explicit deny when python3 is
missing, full resulting-text reconstruction for Write/Edit/MultiEdit
with a specific deny message when unresolvable, and each gate names its
own missing/misordered element in its own deny message. No inter-plugin
`source`; each plugin duplicates the shared shape independently.
`content-design-self-critique` is the one plugin that reads the other
three's section markers directly (for the ordering check) without
calling their scripts, per the proposal's composition design.

`.claude-plugin/marketplace.json` — five new entries added alongside the
existing `content-design` entry; six `content-design*` plugins total.

`docs/handbooks/content-design/methodology.md` — new, per-facet steps/
judgment-criteria/prohibitions for both the phase-1 proposal facet and
the phase-2 record facet, plus a table mapping each facet to its
enforcing plugin. `content-design/hooks/directive.sh` is unchanged (no
fifth `PRODUCES` slot exists in `core_role_directive`, confirmed by
issue-1's own finding and re-confirmed here — depth lives in the
handbook, not the directive).

`tests/run-all.sh` — new, thin wrapper sourcing all five plugins' own
test files; running it aggregates pass/fail without any shared test
logic living outside the plugins.

This record itself is the phase-2 deliverable for the enforcement
machinery; no copy string was touched in this issue (the deliverable is
the gate/plugin set, not a copy change), so the phase-2 record facet's
per-copy-string components (rationale/tone/A-B/self-critique on an
actual string) do not apply to this record — named and skipped per the
proposal's own evidence-format discipline, not silently omitted. Those
components apply to future content-design records that ship real copy,
where the five plugins above will fire against `docs/issue-<n>/reports/
content-design.md` and check them mechanically.

## Verification

- `bash tests/run-all.sh` from repo root: all five plugin test suites
  pass (see table above for per-plugin counts).
- `.claude-plugin/marketplace.json` lists six `content-design*` entries,
  each independently loadable and independently kill-switchable.
- No plugin's file was touched by another plugin's build step (verified
  per-plugin during construction); no plugin sources another's script.
- Core canon's `record-fields-gate.sh` (§20 generic fields) remains
  wired at the core-canon level only, unchanged — these five gates are
  additive on top of it per the proposal's (2) closing note.

## Open findings

None blocking. Carried-forward open questions from the proposal (exact
keyword list for decision-rationale's structural match; whether
`RECORD_FIELDS_TERMINAL_STATES` needs a content-design-specific value)
were resolved during implementation: the decision-rationale gate's exact
match set is now fixed in `content-design-decision-rationale/hooks/
decision-rationale-gate.sh` itself (arrow/because/so-that + `decision`
proximity check); no `RECORD_FIELDS_TERMINAL_STATES` override was needed
— `landed` (this record's own `loop_state`) matches the core default.
