---
subject: issue-7
role: content-design
loop_state: scope-proposed
---

# Proposal: enforce the issue-1 methodology mechanically (phase 1)

Phase-1 only: research + design. No plugin files change in this PR.
Phase 2 opens only on an Approve per contract v3 s19. Basis:
`docs/issue-7/reports/content-design/survey.md` (current-state survey)
and `docs/issue-7/reports/content-design/scout-brief.md` (internal
exemplar scout: `pricing-rulebook`'s `methodology-gate.sh`,
`implementation-rulebook`'s `coding-progress-gate.sh`/`state.sh`).

## Request (paraphrased intent)

Issue-1 adopted a five-component content-design methodology (copy draft,
decision-tied rationale, NN Group 4-axis tone check, testable A/B
variant spec, self-critique note) but reflected it as documentation only
— a one-line `PRODUCES` summary and a proposal-shaped handbook, with no
mechanical check. Issue #7 asks this maturation gap be closed to
`implementation-rulebook`'s hook-machine standard: (1) deepen the
directive's guidance per facet, (2) add a `PreToolUse` methodology gate
checking the adopted `produces` elements mechanically, with state
tracking if a real ordering constraint exists, (3) gate tests, (4)
agents/checklists if a repeated procedure needs one. Canon scripts
referenced only, never copied (`docs/handbooks/canon-scripts.md`).

## (1) Directive depth — per-facet steps, judgment criteria, prohibitions

`directive.sh`'s `PRODUCES` line stays a one-line summary — core canon's
`role-directive.sh` has no fifth slot (confirmed in issue-1's own
finding, unchanged since). Depth belongs in a new handbook,
`docs/handbooks/content-design/methodology.md`, mirroring
`docs/handbooks/pricing/methodology.md`'s pattern ("gate = mechanical
minimum, handbook = worked guidance"). Content (drawn from the already-
adopted issue-1 norm, not new field research — this issue enforces, it
does not re-adopt):

**Phase-1 proposal facet:**
1. *Steps*: current-state survey → scout (or stated skip) → proposal,
   per the standing scout-directive (procedural, not duplicated here).
2. *Judgment criteria*: every proposed copy/pattern change states which
   named user decision it serves before stating why the wording changes
   (issue-1 (a)2) — a rationale that doesn't name the decision fails
   this facet regardless of how well-written the prose is.
3. *Prohibitions*: no "sounds better"/"clearer"/"more friendly" as a
   complete rationale; no unsourced "industry standard" claims; no
   resurrecting practices the field has already refuted for this role
   (issue-1 scout-brief's refuted-claims list, if any resurface).

**Phase-2 record facet, per copy string touched:**
1. *Steps*: draft → rationale → tone-axis check (or skip-reason) → A/B
   spec (or "not applicable" + why) → self-critique, in that order,
   because self-critique's own definition (issue-1 (b)5) is "check the
   draft against items 2-4" — it is not meaningful before they exist.
2. *Judgment criteria*: tone-axis check names which of the 4 NN Group
   axes (Funny↔Serious, Formal↔Casual, Respectful↔Irreverent,
   Enthusiastic↔Matter-of-fact) is live for this string and where it
   targets; a skip is valid only with a one-line reason (e.g. fixed
   legal string). A/B spec, when given, isolates exactly one changed
   element and names the user-behavior signal that would prefer the
   variant. Self-critique is a genuine check, not a restatement — it
   must be able to say "this fails axis-check X" and not merely "looks
   good."
3. *Prohibitions*: no string ships with a tone-axis section that is
   silently absent (must be present-or-skipped-with-reason, never just
   missing); no self-critique note that doesn't reference the rationale/
   tone/A-B content it's checking; no A/B spec with more than one varied
   element.

## (2) Methodology gate — mechanical produces check

New `content-design/hooks/methodology-gate.sh` (`PreToolUse`,
`Write|Edit|MultiEdit`), directly modeled on
`pricing/hooks/methodology-gate.sh` (survey.md §3), never copied
(canon-scripts.md's clause applies to files under `core/hooks/`;
`pricing/hooks/methodology-gate.sh` is itself a per-role file in another
rulebook, referenced here only as a design model, not invoked or
vendored — no file from another rulebook is imported into this tree).

- **Scope regex**: fires only on writes resolving under
  `docs/issue-[0-9]+/proposals/.*content-design.*\.md` (phase-1) or
  `docs/issue-[0-9]+/reports/content-design\.md` (phase-2) — identical
  scoping shape to the pricing gate, substituting this role's own write
  surfaces (which never overlap another role's, preserving write_scope).
- **Fail-closed shape**: trap-at-top (`__fc`/`trap ... EXIT` → exit 2 on
  any abnormal termination), kill switch
  `CONTENT_DESIGN_METHODOLOGY_GATE_OFF` with the standard
  `""|0|false|no|off` = not-off convention, `python3` required with an
  explicit deny (not a silent skip), full resulting-text reconstruction
  for Write/Edit/MultiEdit (denying with a specific "cannot determine
  resulting content" message when a diff-shaped Edit can't be resolved)
  — all identical to the pricing gate's proven shape (survey.md's
  kill-switch/fail-closed conventions section).
- **Required elements checked** (phase-1 proposal target): a stated
  survey+scout basis reference (or documented skip per scout-directive),
  a decision-tied-rationale statement naming what a rationale must
  contain, required-sections presence (Basis / adoption table or copy
  table / evidence-format statement).
- **Required elements checked** (phase-2 record target), per the
  five components: copy draft present; rationale phrased as
  `[decision] → [why]` (checked structurally — presence of an arrow-
  shaped or "because"/"so that" construction tied to a named decision
  keyword, not full NLP judgment); tone-axis section present naming one
  of the four axis pairs, **or** an explicit skip phrase + reason;
  A/B section present **or** an explicit "not applicable" + reason;
  self-critique section present. Missing elements are named together in
  one deny message, exactly like the pricing gate's `missing.append(...)`
  pattern — never one gate invocation per element.
- **The one ordering check this methodology actually has** (survey.md
  §5): when a self-critique section is present, it must appear
  *after* the rationale and tone-axis sections in document order
  (line-offset check: self-critique section's start position > both
  other sections' start positions). This is intra-document positional
  checking, not cross-role state — no `loop_state`-based state tracking
  is needed or proposed, because content-design's adopted methodology
  has no cross-role/cross-document handoff analogous to coding/verify's
  blocking-finding dependency (survey.md §4-5 explicitly find no such
  constraint to enforce).
- **Not duplicated**: core's `record-fields-gate.sh` (§20 generic fields:
  what-was-done/why/upstream-basis/loop_state/open-findings) stays
  wired in at the core-canon level (referenced by path, not vendored);
  this new gate is additive on top of it, checking only this role's
  domain-specific five components, exactly as the pricing gate is
  additive on top of the same core gate (its own file header states
  this explicitly).

## (3) Gate tests

Add `tests/methodology-gate.test.sh` at the repo root (this repo
currently has no root `tests/` — new directory), following the
convention both reference repos use (`pricing-rulebook`'s
`hooks/tests/stub-check.sh`, `implementation-rulebook`'s
`tests/run-gate-tests.sh`): construct sample `Write`/`Edit` tool-call
JSON payloads on stdin, invoke `content-design/hooks/methodology-gate.sh`
directly, and assert exit code.

Required cases (pass/deny), phase 2 will implement all of them:
1. Phase-2 record with all five components in correct order → exit 0.
2. Phase-2 record missing tone-axis section and no skip reason → exit 2,
   message names `tone-axis`.
3. Phase-2 record missing self-critique → exit 2.
4. Phase-2 record with self-critique textually *before* rationale →
   exit 2 (ordering check).
5. Phase-2 record with tone-axis explicitly skipped + reason → exit 0
   (skip is valid, not a missing element).
6. Phase-1 proposal missing decision-tied-rationale statement → exit 2.
7. A write outside the scope regex (e.g. `docs/issue-7/reports/coding.md`)
   → exit 0, gate does not fire (scope check).
8. Malformed/unparseable JSON payload → exit 2 (fail-closed).
9. Kill switch set → exit 0 unconditionally.

Test harness itself is new to this repo but does not copy any
`core/hooks/tests/*` file — it references the shape/convention only, per
the same "referenced, never copied" clause applied one level down (the
convention is a pattern, not a canon-manifest-listed file).

## (4) Agents / checklists

No new `content-design/agents/` directory. Issue-1's adopted methodology
has exactly one repeated procedure (the five-component sequence,
per-string) and it is small enough to live entirely inside the handbook
checklist from (1) — there is no multi-turn, stateful, or tool-driven
loop here that an agent definition would add value over a static
checklist (contrast with `pricing-research`'s multi-gate skill, which
genuinely branches on method family; content-design's sequence does not
branch). The handbook produced in (1) doubles as the checklist artifact
the issue's item 4 asks for, conditioned on "if the methodology requires
one" — it does not here, beyond the handbook.

## Rejected alternatives

- **Cross-role `loop_state` state-tracking gate** (coding-progress-gate
  pattern): rejected because content-design's methodology has no
  cross-role handoff to track (survey.md §5) — building one would
  invent an ordering constraint the adopted methodology never specified,
  the same overreach issue-1's own proposal explicitly avoided when it
  chose not to force live A/B execution.
- **Expanding `directive.sh`'s `PRODUCES` line further**: rejected,
  unchanged from issue-1's finding — no fifth slot exists in
  `core_role_directive`; depth belongs in the handbook + gate, not in a
  longer single line.
- **Vendoring `pricing/hooks/methodology-gate.sh` and role-token-swapping
  it**: rejected — it is not a `core/hooks/**` canon file so
  canon-scripts.md's manifest mechanism doesn't cover it directly, but
  copying another rulebook's per-role file verbatim would recreate
  exactly the copy-paste drift class record-fields-gate's promotion
  history (issue-66) was written to stop; this proposal writes a new
  file scoped to this role's own regex/elements, modeled on it, not
  copied from it.

## Plugin reflection plan (phase 2 — not applied in this PR)

- `content-design/hooks/methodology-gate.sh` — new (per (2)).
- `content-design/hooks/hooks.json` — gains one `PreToolUse` entry
  wiring the new gate; `SessionStart` entry unchanged.
- `content-design/hooks/directive.sh` — unchanged (per (1), no fifth
  slot to fill).
- `docs/handbooks/content-design/methodology.md` — new (per (1)).
- `tests/methodology-gate.test.sh` — new (per (3)); `README.md` may need
  a one-line pointer to how to run repo tests if none exists today
  (phase-2 detail).
- `content-design/agents/` — not created (per (4)).
- `docs/issue-7/reports/content-design.md` — phase-2 record, opened
  only after Approve.

## How success will be judged

- A phase-2 record missing tone-axis (and no skip reason) or
  self-critique is rejected by the new gate before it can be committed.
- A record with self-critique appearing before the rationale/tone
  sections it claims to check is rejected (ordering check fires).
- All 9 test cases in (3) pass against the implemented gate.
- `docs/issue-7/reports/content-design.md` (phase 2, once approved)
  records the gate's implementation and the test run's pass/fail
  output for both a passing and a failing sample write.

## Files (write set, once approved)

- `content-design/hooks/methodology-gate.sh` (new)
- `content-design/hooks/hooks.json` (edited — new `PreToolUse` entry)
- `docs/handbooks/content-design/methodology.md` (new)
- `tests/methodology-gate.test.sh` (new)
- `docs/issue-7/reports/content-design.md` (phase-2 record)

## Open questions for phase 2

1. Exact keyword/phrase list the gate matches for "decision-tied
   rationale" structure (arrow/because/so-that constructions) is a
   phase-2 implementation detail; the required *presence and shape* is
   fixed by this proposal, exact regex is mechanical.
2. Whether `RECORD_FIELDS_TERMINAL_STATES` needs a content-design-
   specific value (core gate already supports per-role config via env
   var, per `record-fields-gate.sh`'s own header) — current default
   (`landed`) appears sufficient per issue-1's precedent; phase 2
   confirms no change needed unless a concrete conflict surfaces.
