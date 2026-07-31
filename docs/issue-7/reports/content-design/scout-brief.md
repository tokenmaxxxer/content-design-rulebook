# Issue #7 — Scout brief (role: content-design)

Scope note: this is an internal-tooling task (hook-machine design), not a
domain-content task — there is no external product category to sweep.
The issue text names the relevant "field" itself: `pricing-rulebook`'s
`methodology-gate.sh` and `implementation-rulebook`'s hook machine. Scout
= reading those two internal exemplars in depth (survey.md §3-4), not a
web sweep. Mode: **batched-sequential, single session** (Read calls on
named local files), not parallel fan-out — stated explicitly per
scout-directive's fallback-disclosure rule; a 4-angle web sweep has no
target here since the exemplars were named by the issue itself. Stages
used: 1 (the survey read doubled as the scout pass; no separate
deepening round changed a build decision — saturation reached
immediately since both exemplars are small, complete files).

## Must-bes (from the two exemplars, convergent)
- Fail-closed trap-at-top + explicit kill switch, `python3` required
  with a deny (not silent skip) if absent — every gate examined does
  this identically.
- Gate exits `0` (pass-through) the instant a write falls outside its
  own scope regex — no gate reaches broader than its named write
  surface.
- Content-shape gates (pricing) reconstruct the full resulting text and
  keyword-match required elements, denying with the specific missing
  element names in one message.
- Order/state gates (coding) derive state from **existing record
  frontmatter/fields** (`loop_state:`) rather than a separate state
  file on disk.

## Performance axes
1. Content-shape strictness (how many required elements, how precisely
   matched) vs. false-positive risk on legitimate prose.
2. Whether an order constraint exists at all — pricing has none
   (single-document, linear); coding's is genuine (cross-role, via
   `loop_state`).

## Adopt / skip
- **Adopt**: pricing's content-shape gate shape wholesale (scope regex,
  full-text reconstruction, one-shot missing-element list, fail-closed
  trap, kill switch) — content-design's five components are exactly
  this shape of check.
- **Skip**: coding's cross-role `loop_state` state-tracking — content-design's adopted methodology (issue-1) has no cross-role/cross-document
  ordering requirement (survey.md §5); building one would invent a
  constraint the methodology never specified.

## Gap line
Field's must-be "gate exists at all, checking the adopted checklist
mechanically" — currently **absent** for content-design (survey.md §1-2,
gap 1). Field's must-be "cross-role state tracking for genuine ordering
constraints" — **not applicable**; this role's adopted methodology
carries only one intra-document ordering fact (self-critique checks
*against* rationale/tone/A-B, so must reference them), which a
content-shape gate can check without any stateful mechanism.

Sources: `pricing/hooks/methodology-gate.sh`,
`docs/handbooks/pricing/methodology.md`,
`docs/issue-1/proposals/methodology-norms.md` (all in
`pricing-rulebook` repo, `main`); `coding/hooks/coding-progress-gate.sh`,
`warrant/hooks/state.sh` (in `implementation-rulebook`/`tokenmaxxxer-core`
repos, `main`); `docs/handbooks/canon-scripts.md`,
`core/hooks/record-fields-gate.sh` (`tokenmaxxxer-core`, `main`).
